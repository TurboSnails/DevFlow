## MODIFIED Requirements

### Requirement: `/dev-flow:update` refreshes the current client installation
An installed `/dev-flow:update` control SHALL invoke the project-root installer for its owning client target and SHALL report the installer's result. If the installer is absent, it SHALL report plainly that the installer is unavailable and SHALL not attempt an alternative update mechanism.

#### Scenario: Refresh an installed target
- **WHEN** a user invokes the update control installed for Cursor and the project-root installer exists
- **THEN** the control invokes the installer with the `cursor` target and reports its output

#### Scenario: Installer script is not present
- **WHEN** a user invokes an installed update control and the project-root installer does not exist
- **THEN** the control reports that the installer is unavailable and takes no action rather than guessing at an alternative update mechanism
