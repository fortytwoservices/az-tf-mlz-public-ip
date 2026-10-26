# Example with interfaces

A zone-redundant public IP with a DNS label, diagnostic settings (all log category groups and all
metrics) sent to a Log Analytics workspace, a `CanNotDelete` lock and a Reader role assignment for the
identity that runs the example. Next to it, a locked /31 prefix whose diagnostic settings send one log
category. The second plan must be empty, which proves Azure's extra disabled log entries are ignored.
