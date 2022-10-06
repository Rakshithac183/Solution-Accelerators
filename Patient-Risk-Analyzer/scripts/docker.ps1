Start-Transcript -Path C:\WindowsAzure\Logs\logontask.txt -Append

# Install VS COde extension 
code --install-extension ms-azuretools.vscode-docker

#Install WSL
wsl --install -d Debian

#Install Dcoker-Desktop
choco install docker-for-windows -y -force

Unregister-ScheduledTask -TaskName "Setup" -Confirm:$false

Stop-Transcript

