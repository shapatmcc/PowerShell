#Description: This checks if you are already logged into vsphere or not via powershell. If not, it attempts to log in. This can be useful when you want to run a script multiple times without logging in each time. 
 
 function Check-vSphereLogin {
     $servername = "SERVER NAME HERE"
    if(!$global:DefaultVIServer){
        try {
            Connect-VIServer $servername
        } catch {
            Read-Host "Please ensure VMWare.PowerCLI module is installed"
            break
        }
    }
}
