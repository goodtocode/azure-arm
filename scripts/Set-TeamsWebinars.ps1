# Run as Administrator
Install-Module -Name MicrosoftTeams
Connect-MicrosoftTeams
Set-CsTeamsMeetingPolicy -AllowMeetingRegistration $True
Set-CsTeamsMeetingPolicy -WhoCanRegister EveryoneInCompany
# OR Set-CsTeamsMeetingPolicy -WhoCanRegister Everyone
Set-CsTeamsMeetingPolicy -AllowEngagementReport Enabled