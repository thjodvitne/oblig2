# Oblig 2 – utgangspunktet

To tjenester, `ordre` og `meny`, rullet ut i dev og prod. Infrastrukturen er
delt **horisontalt**: én stack per lag, og hver stack dekker begge tjenestene.

| Tjeneste | Nettverk | Data | Kjøring |
|---|---|---|---|
| `ordre` | subnett + NSG | storage account + Key Vault | Linux-VM med nginx og offentlig IP |
| `meny` | subnett (delegert til App Service) + NSG | storage account + Key Vault | App Service-plan (B1) + web app med VNet-integrasjon |

Hva du skal gjøre med dette, står i obligteksten i Canvas.

```text
config/
  felles.tfvars          kortnavn og region – det eneste du endrer på dag 1
  dev/  prod/            én .tfvars per stack per miljø
modules/                 vnet, subnet, storage, keyvault, vm, webapp
stacks/
  network/               ressursgruppa, VNet-et og ett subnett per tjeneste
  data/                  storage account og Key Vault per tjeneste
  app/                   VM-en til ordre og web app-en til meny
shared/backend.hcl       adressen til state-kontoen (den samme som i oblig 1)
scripts/
  kjor.sh                plan eller apply for alle stackene i ett miljø
  valider.sh             porten: fmt, validate, TFLint, Checkov
.github/workflows/
  ci.yml                 på hver PR: porten, og plan mot dev og prod
  cd-dev.yml             merge til main → dev
  cd-prod.yml            for hånd, med SHA-en fra dev → prod (med godkjenning)
reset.sh / Reset.ps1     tilbake til utgangspunktet
```

## Slik finner workflowen stackene

Workflowene kjører `scripts/kjor.sh`, og den har ingen liste over stacker. Den
ser på filene i `config/<miljø>/`. Hver fil er én instans av en stack, med sin
egen state-fil:

```text
config/dev/network.tfvars  →  stacks/network/  →  key oblig2/dev/network.tfstate
```

Heter fila `<type>-<noe>.tfvars` og det ikke finnes en mappe med akkurat det
navnet, brukes `stacks/<type>/`. Da gir to filer to instanser av samme stack.

Rekkefølgen står i `LAG` øverst i `kjor.sh`. En stack som leser outputs fra en
annen med `terraform_remote_state`, må stå etter den. Alle stackene får
`config/felles.tfvars` i tillegg til sin egen fil, og `miljo` og
state-adressen som `TF_VAR_*`.

## Oppsett (dag 1)

Du bruker den samme state-kontoen og den samme App Registration-en som i
oblig 1. Det nye er repoet.

**1. Repoet.** *Use this template* → organisasjonen din fra oblig 1. Gjør
repoet **public**. I en gratis organisasjon er godkjenningsporten på
environments bare tilgjengelig for offentlige repoer.

**2. Azure.** På App Registration-en fra oblig 1: legg til tre federated
credentials for det **nye** repoet, én per environment:

```text
dev  ·  prod-plan  ·  prod
```

Bygg subject-strengen akkurat som i modul 5 side 4, med tallene for
organisasjonen og repoet. Kontroller *Subject identifier* før du lagrer.

**3. GitHub.** Under *Settings → Environments*:

| Environment | Protection rules |
|---|---|
| `dev` | ingen |
| `prod-plan` | ingen. Brukes bare til å *lese* prod i PR-planen |
| `prod` | Required reviewers: deg selv. Prevent self-review: av. Branches: `main` |

Under *Settings → Secrets and variables → Actions*, som repository secrets:
`AZURE_CLIENT_ID`, `AZURE_TENANT_ID` og `AZURE_SUBSCRIPTION_ID`.

**4. Første PR.** Lag en gren, og endre to filer:

- `config/felles.tfvars`: kortnavnet ditt
- `shared/backend.hcl`: kopier verdiene fra `shared/backend.hcl` i oblig
  1-repoet ditt

Lag PR-en. CI kjører porten og planlegger mot dev og prod. `network` skal vise
`to add` og ingenting annet. `data` og `app` viser ⏳: de leser state fra
`network`, og den finnes ikke før `network` er rullet ut. Det gjelder bare
denne første gangen. Merge.

**5. Rull ut.** CD dev starter av seg selv. Når den er grønn: *Actions →
CD prod → Run workflow*, og lim inn SHA-en fra dev-kjøringen. Godkjenn.

**6. Sjekk.** Jobbsammendraget viser outputs fra `app`. Åpne
`http://<vm_public_ips.ordre>` og `https://<webapp_hostnames.meny>`. VM-en
viser en *boot-id*. Den endres bare hvis VM-en bygges på nytt.

**7. Beskytt `main`.** Krev PR, og gjør `kodekontroll`, `plan mot dev` og
`plan mot prod` til required status checks. De kan først velges etter at de
har kjørt én gang.

## Nattjobben

Tenanten sletter alle ressursgrupper uten `keep`-tag hver natt. Ressurs-
gruppene i dette repoet har ingen slik tag. State blir derimot liggende, så om
morgenen sier staten at alt finnes, mens Azure sier at ingenting gjør det.

- **Hver gang du starter en økt:** *Run workflow* på CD dev, og så CD prod.
  Da bygges alt opp igjen fra staten.
- **Migreringen må gjøres ferdig samme dag som du starter den.** Blir den
  avbrutt av nattjobben midt i, står ressurser igjen som ingen stack eier, og
  de er borte om morgenen. Da er det `reset.sh` som gjelder.

Key Vault-ene ligger i soft-delete i 7 dager etter at de er slettet. Terraform
tar dem tilbake når du ruller ut på nytt, så du merker ingenting.

## Kjøre lokalt

```bash
az login
bash scripts/valider.sh              # porten, uten Azure (trenger tflint og checkov)
bash scripts/kjor.sh dev plan        # plan mot dev, som deg selv
```

Kjør `apply` gjennom workflowen, ikke lokalt. Det er workflowen K-kravene ser
på.

## Reset

```bash
./reset.sh                                              # macOS / Linux
powershell -ExecutionPolicy Bypass -File .\Reset.ps1    # Windows
```

Sletter ressursgruppene dine i begge miljøene og state-filene under `oblig2/`,
og lager en gren som henter koden fra første commit tilbake.
`config/felles.tfvars` og `shared/backend.hcl` beholdes. Skriptet spør før det
gjør noe, og forteller hva du gjør videre.

## Delt abonnement

Hele kullet ruller ut i det samme abonnementet, og det har grenser for hvor
mange vCPU-er og App Service-planer som kan stå samtidig. Ikke lag flere VM-er
eller planer enn oppgaven ber om. Får du en kvotefeil
(`Operation cannot be completed without additional quota`), si fra til
faglærer.

## Det som kan gå galt

| Symptom | Årsak |
|---|---|
| `AADSTS700213` ved innlogging | Subject-strengen matcher ikke. Har du laget credentials for det **nye** repoet, med riktige tall? |
| 403 `AuthorizationPermissionMismatch` i `init` | Service principal-en mangler *Storage Blob Data Contributor* på state-kontoen. Gjelder hvis du har laget en ny state-konto |
| `kortnavn må være 2–10 små bokstaver eller tall` | `config/felles.tfvars` er ikke endret ennå |
| `Unable to find remote state` | En stack leser state som ikke finnes ennå. Stacken den leser fra, må være rullet ut i det miljøet først |
| `No available instances to satisfy this request` | App Service har midlertidig for lite kapasitet i regionen. Kjør på nytt litt senere |
| Web app-en svarer ikke, eller tidsavbrudd i nettleseren | Første forespørsel etter en utrulling starter appen, og det kan ta 2–3 minutter. Last siden på nytt |
| `config/dev/<x>.tfvars passer ikke i noe lag` | Fila peker på en stack som ikke finnes, eller som ikke står i `LAG` i `kjor.sh` |
