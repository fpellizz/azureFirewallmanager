#installa moduli necessari

if (Get-Module -ListAvailable -Name Az) {
    #Write-Host "Module PSWriteColor exists"
} 
else {
    Write-Host "Module Az does not exist. Installing..."
    Install-Module -Force -Scope CurrentUser Az
    Write-Host "Module Az installed"
}

if (Get-Module -ListAvailable -Name PSWriteColor) {
    #Write-Host "Module PSWriteColor exists"
} 
else {
    Write-Host "Module PSWriteColor does not exist"
    Install-Module -Force -Scope CurrentUser PSWriteColor
    Write-Host "Module PSWriteColor installed"
}

if (Get-Module -ListAvailable -Name PsIni) {
    #Write-Host "Module PsIni exists"
} 
else {
    Write-Host "Module PsIni does not exist"
    Install-Module -Force -Scope CurrentUser PsIni
    Write-Host "Module PsIni installed"
}

#Importo i moduli necessari

Import-Module -Name PsIni
Import-Module -Name PSWriteColor
Import-Module -Name Az.Accounts
Import-Module -Name Az.PostgreSql

#leggo le informazioni dal file config.ini
$config = Get-IniContent .\config.ini
$version = $config["GLOBAL"]["version"]
$ResourceGroupName = $config["DEFAULT"]["ResourceGroupName"]
$ServerName = $config["DEFAULT"]["ServerName"]
$dblist = $config[$ResourceGroupName]["dblist"]

#poterbbe essere necessario settare le exdcution-policy
#Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

############################
#FUNZIONI

function getFirewallRules {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName,
        [string]$ServerName
    )
    $rulesArray = @()
    $fwrules = Get-AzPostgreSqlFlexibleServerFirewallRule -ResourceGroupName $ResourceGroupName -ServerName $ServerName
    foreach ($fwrule in $fwrules) {
       $rule = "" | Select-Object -Property Name,StartIP,EndIP
       $rule.Name = $fwrule.Name  
       $rule.StartIP =  $fwrule.StartIPAddress 
       $rule.EndIP =  $fwrule.EndIPAddress
       $rulesArray += $rule
    }
    Return $rulesArray
}

function addFirewallRule {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName,
        [string]$ServerName,
        [string]$Name,
        [string]$StartIPAddress,
        [string]$EndIPAddress
    )
    
    if ($StartIPAddress -eq "") {
        $StartIPAddress = (Invoke-WebRequest -uri "http://ifconfig.me/ip").Content
    }

    if ($EndIPAddress -eq "") {
        $EndIPAddress = (Invoke-WebRequest -uri "http://ifconfig.me/ip").Content
    }    

    #check
    try {
        [ipaddress] $StartIPAddress > $null
    }
    catch {
        $message = $_
        Clear-Host
        Write-Warning -Message "Opperbacco! $message"
        Break
    }

    try {
        [ipaddress] $EndIPAddress > $null
    }
    catch {
        $message = $_
        Clear-Host
        Write-Warning -Message "Opperbacco! $message"
        Break
    }    

    try {
        New-AzPostgreSqlFlexibleServerFirewallRule -Name $Name -ResourceGroupName $ResourceGroupName -ServerName $ServerName -EndIPAddress $EndIPAddress -StartIPAddress $StartIPAddress
    }
    catch {
        $message = $_
        Clear-Host
        Write-Warning -Message "Opperbacco! $message"
        Break
    }
}

function deleteFirewallRule {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName,
        [string]$ServerName,
        [string]$Name
    )

    #check
    if ($Name -eq "") {
        Clear-Host
        Write-Warning -Message "Opperbacco! Inserisci un nome per eliminare una regola di firewall"
        Break
    }

    try {
        Remove-AzPostgreSqlFlexibleServerFirewallRule -Name $Name -ResourceGroupName $ResourceGroupName -ServerName $ServerName
    }
    catch {
        $message = $_
        Clear-Host
        Write-Warning -Message "Opperbacco! $message"
        Break
    }
}

function updateFirewallRule {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName,
        [string]$ServerName,
        [string]$Name,
        [string]$StartIPAddress,
        [string]$EndIPAddress
    )
    
    if ($StartIPAddress -eq "") {
        $StartIPAddress = (Invoke-WebRequest -uri "http://ifconfig.me/ip").Content
    }

    if ($EndIPAddress -eq "") {
        $EndIPAddress = (Invoke-WebRequest -uri "http://ifconfig.me/ip").Content
    }    

    #check
    try {
        [ipaddress] $StartIPAddress > $null
    }
    catch {
        $message = $_
        Clear-Host
        Write-Warning -Message "Opperbacco! $message"
        Break
    }

    try {
        [ipaddress] $EndIPAddress > $null
    }
    catch {
        $message = $_
        Clear-Host
        Write-Warning -Message "Opperbacco! $message"
        Break
    }    

    try {
        Update-AzPostgreSqlFlexibleServerFirewallRule -Name $Name -ResourceGroupName $ResourceGroupName -ServerName $ServerName -EndIPAddress $EndIPAddress -StartIPAddress $StartIPAddress
    }
    catch {
        $message = $_
        Clear-Host
        Write-Warning -Message "Opperbacco! $message"
        Break
    }
}

function getDefaultResourceGroupName {
    Clear-Host
    Write-Output "########################################################################################################################"
    Write-Output "L'Azure Resource Group impostato come default e' : "
    Write-Output ""
    Write-Output $ResourceGroupName
    Write-Output ""
    Write-Output "Per modificare l'account di default utilizzare $PSCommandPath Set-DefaultResourceGroupName resource_group_name"
    Write-Output ""
    Write-Output "########################################################################################################################"
}

function getResourceGroupNameList {
    Clear-Host
    Write-Output "########################################################################################################################"
    Write-Output "I Resource Groups censiti sono: "
    Write-Output ""
    Write-Output $config["RESOURCEGROUPS_LIST"].Keys
    Write-Output ""
    Write-Output "Se il Gruppo di Risorse che cerchi non e' presente in lista, contatta l'amministratore"
    Write-Output "########################################################################################################################"
}

function setDefaultResourceGroupName {
    param(
        [Parameter(Mandatory = $true)]
        [string]$newDefaultResourceGroupName
    )
    #check
    $known = $config["RESOURCEGROUPS_LIST"].Keys
    
    if ( -not ($newDefaultResourceGroupName -in $known )) {
        Clear-Host
        Write-Warning "Resource Group non valido"
        Break
    }

    try {
        $config["DEFAULT"]["ResourceGroupName"] = $newDefaultResourceGroupName
        $config | Out-IniFile -Force -FilePath .\config.ini
    }
    catch {
        $message = $_
        Write-Warning -Message "Opperbacco! $message"
    }
}

function getDatabaseList {
    Clear-Host
    $databaseList = Get-AzPostgreSqlFlexibleServer -ResourceGroupName $ResourceGroupName
    Clear-Host
    Write-Output "########################################################################################################################"
    Write-Output "I database presenti nel Resource Groups sono: "
    Write-Output ""
    foreach ($database in $databaseList) {
        Write-Host $database.Name
    }
    Write-Output ""
    Write-Output "########################################################################################################################"

}

function getDefaultDatabase {
    Clear-Host
    Write-Output "########################################################################################################################"
    Write-Output "Il Database impostato come default e': "
    Write-Output ""
    Write-Output $config["DEFAULT"]["ServerName"]
    Write-Output ""
    Write-Output "########################################################################################################################"
}

function setDefaultDatabase {
    param(
        [Parameter(Mandatory = $true)]
        [string]$newDefaultDatabase
    )
    #check
    $dbArray = @()
    $dbs = Get-AzPostgreSqlFlexibleServer -ResourceGroupName $ResourceGroupName
    foreach ($db in $dbs) {
       $dbArray += $db.Name
    }


    if ( -not ($newDefaultDatabase -in $dbArray )) {
        Clear-Host
        Write-Warning "Nome Database non valido"
        Break
    }

    try {
        $config["DEFAULT"]["ServerName"] = $newDefaultDatabase
        $config | Out-IniFile -Force -FilePath .\config.ini
    }
    catch {
        $message = $_
        Write-Warning -Message "Opperbacco! $message"
    }
}


function info {
    Clear-Host
    Write-Output "########################################################################################################################"
    Write-Output "  AzureFirewallManager e' uno script PowerShell che dovrebbe permettere di gestire"
    Write-Output "  le regole di firewall su database Azure."
    Write-Output "  Azure PostgreSql Flexible Server per l'esattezza"
    Write-Output ""
    Write-Output "  Per gestire intendo creare, eliminare ed aggiornare, al momento."
    Write-Output "  E credo anche per il futuro..."
    Write-Output ""
    Write-Output "  Realizzato e manutenuto da:"
    Write-Output ""
    Write-Output "     - Fabio Pellizzaro (mail: fabio.pellizzaro@decisyon.com)"
    Write-Output ""
    Write-Output ""
    Write-Output ("  Versione: $version")
    Write-Output "########################################################################################################################"
}

function help {

    Clear-Host
    Write-Host "  AzureFirewallManager uno script  PowerShell nato con l'intenzione di fornire la possibilità"
    Write-Host "  di gestire le regole di firewall relative ad un Azure Postgresql Flexible Server."
    Write-Host " "
    Write-Host "  Utilizzo:"
    Write-Host " "
    Write-Host "  - help: " -ForegroundColor Yellow
    Write-Host "    Produce questo help "
    Write-Host "    esempio: " -ForegroundColor DarkGray
    Write-Host "    $PSCommandPath help " -ForegroundColor DarkGray
    Write-Host " "
    Write-Host "  - Get-FirewallRules: " -ForegroundColor Yellow
    Write-Host "    Ritorna tutte le regole di firewall definite nel database (e resource group) di default, riportando anche gli indirizzi ip definiti."
    Write-Host "    esempio: " -ForegroundColor DarkGray
    Write-Host "    $PSCommandPath Get-FirewallRules" -ForegroundColor DarkGray
    Write-Host " "
    Write-Host "  - Add-FirewallRule: " -ForegroundColor Yellow
    Write-Host "    Aggiunge una regola di firewall nel database impostato come default."
    Write-Host "    Parametri:" -ForegroundColor Cyan
    Write-Host "      Name: il nome della regola che si vuole creare."
    Write-Host "      StartIPAddress: Indirizzo ip iniziale"
    Write-Host "      EndIPAddress: Indirizzo ip finale"        
    Write-Host "    esempio: " -ForegroundColor DarkGray
    Write-Host "    $PSCommandPath Add-FirewallRule smartworking 98.23.42.13 98.23.42.13" -ForegroundColor DarkGray
    Write-Host " "
    Write-Host "  - Delete-FirewallRule: " -ForegroundColor Yellow
    Write-Host "    Rimuove una regola di firewall presente nel database impostato come default."
    Write-Host "    Parametri:" -ForegroundColor Cyan
    Write-Host "      Name: il nome della regola che si vuole eliminare."    
    Write-Host "    esempio: " -ForegroundColor DarkGray
    Write-Host "    $PSCommandPath Delete-FirewallRule smartworking" -ForegroundColor DarkGray    
    Write-Host " "
    Write-Host "  - Update-FirewallRule: " -ForegroundColor Yellow
    Write-Host "    Aggiorna il valore dell'indirizzo ip iniziale e dell'indirizzo ip finale di una regola presente nel database definito come default."
    Write-Host "    In caso non vengano forniti i parametri "StartIPAddress" e "EndIPAddress", lo script utilizza automaticamente l'idirizzo ip pubblico" 
    Write-Host "    della connessione utilizzata, ricavato dal sito http://ifconfig.me/ip ."
    Write-Host "    Ad esempio, nel caso si lavori da casa senza un ip statico, è sufficiente lanciare il comando di update specificando il nome della" 
    Write-Host "    regola da aggiornare e lo script automaticamente imposterà l'indirizzo ip della connessione utilizzata."
    Write-Host "    Parametri:" -ForegroundColor Cyan
    Write-Host "      Name: il nome della regola che si vuole creare."
    Write-Host "      StartIPAddress: Indirizzo ip iniziale"
    Write-Host "      EndIPAddress: Indirizzo ip finale"        
    Write-Host "    esempio: " -ForegroundColor DarkGray
    Write-Host "    #aggiornare regola specificando indirizzo ip" -ForegroundColor DarkGray
    Write-Host "    $PSCommandPath Add-FirewallRule smartworking 98.23.42.13 98.23.42.13" -ForegroundColor DarkGray
    Write-Host " "
    Write-Host "    #aggiornare regola autorilevamento indirizzo ip" -ForegroundColor DarkGray
    Write-Host "    $PSCommandPath Add-FirewallRule smartworking " -ForegroundColor DarkGray
    Write-Host " "
    Write-Host "  - Get-ResourceGroupNameList: " -ForegroundColor Yellow
    Write-Host "    Ritorna la lista dei Resource Group censiti nel file di configurazione."
    Write-Host "    esempio: " -ForegroundColor DarkGray
    Write-Host "    $PSCommandPath Get-ResourceGroupNameList" -ForegroundColor DarkGray
    Write-Host " "
    Write-Host "  - Get-DefaultResourceGroupName: " -ForegroundColor Yellow
    Write-Host "    Ritorna il nome del Resource Group impostato come default."
    Write-Host "    esempio: " -ForegroundColor DarkGray
    Write-Host "    $PSCommandPath Get-DefaultResourceGroupName" -ForegroundColor DarkGray
    Write-Host " "
    Write-Host "  - Set-DefaultResourceGroupName: " -ForegroundColor Yellow
    Write-Host "    Imposta il Resource Group di default."
    Write-Host "    Parametri:" -ForegroundColor Cyan
    Write-Host "      Name: il nome della regola che si vuole eliminare."    
    Write-Host "    esempio: " -ForegroundColor DarkGray
    Write-Host "    $PSCommandPath Set-DefaultResourceGroupName testgroupname" -ForegroundColor DarkGray
    Write-Host " "
    Write-Host "  - Get-DatabaseList: " -ForegroundColor Yellow
    Write-Host "    Ritorna la lista dei database presenti nel Resource Group definito come default."
    Write-Host "    esempio: " -ForegroundColor DarkGray
    Write-Host "    $PSCommandPath Get-DatabaseList" -ForegroundColor DarkGray
    Write-Host " "
    Write-Host "  - Get-DefaultDatabase: " -ForegroundColor Yellow
    Write-Host "    Ritorna il database definito come default."
    Write-Host "    esempio: " -ForegroundColor DarkGray
    Write-Host "    $PSCommandPath Get-DefaultDatabase" -ForegroundColor DarkGray
    Write-Host " "
    Write-Host "  - Set-DefaultDatabase: " -ForegroundColor Yellow
    Write-Host "    Imposta il database di default."
    Write-Host "    Lo script esegue un controllo sul nome database passato come parametro e nel caso" 
    Write-Host "    il database non esista nel Resource Group, ritorna un errore."
    Write-Host "    Parametri:" -ForegroundColor Cyan
    Write-Host "      Name: il nome della regola che si vuole eliminare."    
    Write-Host "    esempio: " -ForegroundColor DarkGray
    Write-Host "    $PSCommandPath Set-DefaultDatabase postgresql-test" -ForegroundColor DarkGray
}



############################
#MAIN
$azione = $args[0]
$parametro = $args[1]
$altroparametro = $args[2]
$altroparametroancora = $args[3]

switch -Wildcard ($azione)
{
    Get-FirewallRules { 
        #Write-Output "$azione"
        #effettuo il login via web, purtroppo per ora non sono riuscito a fare di meglio
        Login-AzAccount > $null
        $pippo = getFirewallRules -ResourceGroupName $ResourceGroupName -ServerName $ServerName
        Write-Host "Regole di Firewall presenti:"
        foreach ($element in $pippo) {
            $NomeRegola = $element.Name
            $StartIPRegola = $element.StartIP
            $EndIPRegola = $element.EndIP
            Write-Host ("Nome: $NomeRegola [$StartIPRegola - $EndIPRegola]")
        }
    }
    Add-FirewallRule { 
        #Write-Output "$azione"
        #effettuo il login via web, purtroppo per ora non sono riuscito a fare di meglio
        Login-AzAccount > $null
        addFirewallRule -ResourceGroupName $ResourceGroupName -ServerName $ServerName -Name $parametro -StartIPAddress $altroparametro -EndIPAddress $altroparametroancora
    }
    Delete-FirewallRule { 
        #Write-Output "$azione"
        #effettuo il login via web, purtroppo per ora non sono riuscito a fare di meglio
        Login-AzAccount > $null
        deleteFirewallRule -ResourceGroupName $ResourceGroupName -ServerName $ServerName -Name $parametro
    }
    Update-FirewallRule { 
        #Write-Output "$azione"
        #effettuo il login via web, purtroppo per ora non sono riuscito a fare di meglio
        Login-AzAccount > $null
        updateFirewallRule -ResourceGroupName $ResourceGroupName -ServerName $ServerName -Name $parametro -StartIPAddress $altroparametro -EndIPAddress $altroparametroancora
    }
    Get-ResourceGroupNameList { 
        #Write-Output "$azione"
        getResourceGroupNameList; 
        Break 
    }
    Get-DefaultResourceGroupName { 
        #Write-Output "$azione"
        getDefaultResourceGroupName; 
        Break
    }
    Set-DefaultResourceGroupName { 
        #Write-Output "$azione"
        #Write-Output $parametro
        if ($parametro -eq "") {
            Write-Warning "Resource Group name not valid!"
            Break
        }
        setDefaultResourceGroupName -newDefaultResourceGroupName $parametro
        Break
    }

    Get-DatabaseList { 
        #Write-Output "$azione"
        getDatabaseList; 
        Break 
    }
    Get-DefaultDatabase { 
        #Write-Output "$azione"
        getDefaultDatabase; 
        Break
    }
    Set-DefaultDatabase { 
        #Write-Output "$azione"
        #Write-Output $parametro
        if ($parametro -eq "") {
            Write-Warning "Database name not valid!"
            Break
        }
        setDefaultDatabase -newDefaultDatabase $parametro
        Break
    }
    
    help { 
        Write-Output "$azione"
        help 
    }
    info { 
        #Write-Output "$azione"
        info
    }
    test { 
        Write-Output "$azione" -ForegroundColor Yellow
    }
    Default {
        Write-Output ""
        Write-Output "Please give me some info about what the hell you want to do"
        Write-Output ""
        Write-Output "if you need help, please run $PSCommandPath help"
        Write-Output ""        
    }
}