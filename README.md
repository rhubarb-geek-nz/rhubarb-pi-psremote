Package `rhubarb-pi-psremote` adds and removes a single line in the `/etc/ssh/sshd_config` file.

```
Subsystem powershell /usr/bin/pwsh -sshs -nologo
```

Installing the package adds the line, removing the package removes the line.

Package dependencies include both `openssh-server` and `powershell`.

The [package.sh](linux/package.sh) script creates both `deb` and `rpm` packages.

The `openssh-server` will need restarting after installing the package.

Test installation with

```
PS> Invoke-Command -HostName localhost -ScriptBlock { $HOST }

PSComputerName   : localhost
RunspaceId       : 4eeac115-38b4-4ad6-ab02-013c99458b45
Name             : ServerRemoteHost
Version          : 7.4.0
InstanceId       : 12758db3-7b67-4923-9a6b-3efa12551895
UI               : System.Management.Automation.Internal.Host.InternalHostUserInterface
CurrentCulture   :
CurrentUICulture :
PrivateData      :
DebuggerEnabled  : True
IsRunspacePushed : False
Runspace         : System.Management.Automation.Runspaces.LocalRunspace

```

See [PowerShell remoting over SSH](https://learn.microsoft.com/en-us/powershell/scripting/learn/remoting/ssh-remoting-in-powershell).
