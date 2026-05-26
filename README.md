# PULSAR-ARCADE

This was taken from the original sandbox framework fork converted to pulsar framework and fully configured to work as before in the mythic/sandbox forks it was not complete

**A competitive PvP arcade resource built for the Avast Arcade job.**

## Overview

Pulsar-Arcade is a PvP arcade resource built for the Avast Arcade job, featuring instanced routing buckets, custom loadouts , and custom maps

## How it works
An Avast Arcade employee can clock in and open the arcade for operation. Once active, the employee is able to create and configure custom PvP matches directly through the arcade system. Players can then join the active match before it begins.

After all participants have joined, the employee can start the match, automatically transferring all players into a separate routing bucket dedicated to the arena session. Upon entering the match, player inventories are placed into a confiscated state to ensure a fair and controlled gameplay environment.

Matches will automatically end after either:

10 minutes have passed, or
A player reaches 25 kills.

Once the match concludes, all participants are returned back to the arcade location, removed from the match routing bucket, and their confiscated inventories are fully restored.


## Dependencies

- [pulsar-core](https://github.com/PulsarFW/pulsar-core)

## License

Copyright © 2026 Pulsar Framework. All rights reserved.
