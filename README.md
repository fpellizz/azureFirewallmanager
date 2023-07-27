# AzureFirewallManager for PowerShell

Semplice script PowerShell nato con l'intenzione di fornire la possibilità

di avviare gestire le regole di firewall relative ad un Azure Postgresql Flexible Server.



### Dipendenze

Utilizza due moduli PowerShell:

* PsIni

* Az

* PSWriteColor

Tali moduli se non presenti vengono automaticamente installati a livello utente.

### Struttura

Il tool di gestione per le istanze EC2 si compone di tre file:

* **AzureFirewallManager.ps1 :** Lo script PowerShell contenente tutta la logica e le funzioni necessarie alla gestione delle regole di firewall

* **config.ini :** File di configurazione.

### Setup

Non è necessaria un'installazione vera e propria, essendo uno script PowerShell.

E' sufficiente clonare (o scaricare) il repository aprire una PowerShell ed andare ad eseguire lo script AzureFirewallManager.ps1 , prestando attenzione alla presenza nello stesso path dello script del file config.ini

Potrebbe essere necessario abilitarne l'esecuzione andando ad impostare le ExecityonPolicy:

```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass
```

### Come funziona

AzureFirewallManager è fornito di un solido help che spiega abbastanza dettagliatamente il funzionamento e le operazioni che è in grado di compiere.

#### - help:

Mostra a schermo l'help.

```powershell
.\AzureFirewallManager.ps1 help
```

#### - Get-FirewallRules:

Ritorna tutte le regole di firewall definite nel database (e resource group) di default, riportando anche gli indirizzi ip definiti. 

##### Esempio:

```powershell
.\AzureFirewallManager.ps1 Get-firewallRules
```

#### - Add-FirewallRule:

Aggiunge una regola di firewall nel database impostato come default.

##### Parametri:

- **Name :** il nome della regola che si vuole creare.
- **StarIPAddress:** Indirizzo ip iniziale
- **EndIPAddress:** Indirizzo ip finale

##### Esempio:

```powershell
.\AzureFirewallManager.ps1 Add-FirewallRule smartworking 98.23.42.13 98.23.42.13
```

#### - Delete-FirewallRule:

Rimuove una regola di firewall presente nel database impostato come default.

##### Parametri:

- **Name :** il nome della regola da eliminare

##### Esempio:

```powershell
.\AzureFirewallManager.ps1 Delete-FirewallRule smartworking
```

##### - Update-FirewallRule

Aggiorna il valore dell'indirizzo ip iniziale e dell'indirizzo ip finale di una regola presente nel database definito come default.

In caso non vengano forniti i parametri "StartIPAddress" e "EndIPAddress", lo script utilizza automaticamente l'idirizzo ip pubblico della connessione utilizzata, ricavato dal sito http://ifconfig.me/ip .

Ad esempio, nel caso si lavori da casa senza un ip statico, è sufficiente lanciare il comando di update specificando il nome della regola da aggiornare e lo script automaticamente imposterà l'indirizzo ip della connessione utilizzata. 

Parametri:

- **Name :** il nome della regola da aggiornare
- **StarIPAddress:** Indirizzo ip iniziale (opzionale)
- **EndIPAddress:** Indirizzo ip finale (opzionale)

##### Esempio:

```powershell
# per aggiornare la regola specificando un indirizzo ip
.\AzureFirewallManager.ps1 Uppdate-FirewallRule smartworking 34.10.120.23 34.10.120.23

# per aggiornare la regola in modo automatico
.\AzureFirewallManager.ps1 Uppdate-FirewallRule smartworking
```

#### - Get-ResourceGroupNameList:

Ritorna la lista dei Resource Group censiti nel file di configurazione

##### Esempio:

```powershell
.\AzureFirewallManager.ps1 Get-ResourceGroupNameList
```

#### - Get-DefaultResourceGroupName:

Ritorna il nome del Resource Group impostato come default

##### Esempio:

```powershell
.\AzureFirewallManager.ps1 Get-DefaultResourceGroupName
```

#### - Set-DefaultResourceGroupName:

Imposta il Resource Group di default.

Parametri:

- **nome:** il nome del Gruppo di Risorse da impostare come default

##### Esempio:

```powershell
.\AzureFirewallManager.ps1 Set-DefaultResourceGroupName testgroupname
```

#### - Get-DatabaseList:

Ritorna la lista dei database presenti nel Resource Group definito come default.

##### Esempio:

```powershell
.\AzureFirewallManager.ps1 Get-DatabaseList
```

#### - Get-DefaultDatabase:

Ritorna il database definito come default.

##### Esempio:

```powershell
.\AzureFirewallManager.ps1 Get-DefaultDatabase
```

#### - Set-DefaultDatabase:

Imposta il database di default. 

Lo script esegue un controllo sul nome database passato come parametro e nel caso il database non esista nel Resource Group, ritorna un errore. 

Parametri:

- **nome:** il nome del database da impostare come default

##### Esempio:

```powershell
.\AzureFirewallManager.ps1 Set-DefaultDatabase postgresql-test
```



### TO DO

* Scrivere l'help dello script.

* Implementare un sistema di login che non richieda ogni volta l'accesso via web