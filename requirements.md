MacOS menu app
This app monitors running coding agents, using cli agj

It has a menu bar item.

Icon of menu bar item has 2 states:
- Normal state: No agents asking for permission
- Asking for permission state: there's agent asking

When users click the menu bar:
- It should have a session list there, showing list of agents

This list should be grouped by iterm tab id (shown as iterm tab title)
Each session is shown as:
- Codex/Claude
    Directory

This list is refreshed by refresh interval setting

Then there should be setting page (accessed from menu):
There 2 tabs in setting:
- 1 is for normal working stuff:
    - Refresh interval, default is 3 sec
    - Want to get notification on agent asking for permission?
    - Notification sound
1 is for onboarding, to check for permission
    - agj: Should check if agj cli is available, and show status
    There should be a setting to manually set agj path to run as well
    - Iterm python enabled?
    - Notification permission granted or not

Should check how codexbar handle environment path to look for agj.


Build script: Should have sign step