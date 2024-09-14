# aspiringBlu

## Overview
aspiringBlu is a project designed to help learn Blue Magic.

## Features
- Zone Checker: Each time you change zones, it will check if there are any Blue Magic spells unlearned in the area; if there are, it will list all the spells and the mobs. You can learn them from, accompanied by a text and speech sound.
- Recheck Zone: Using the command `//aspblu check` or `//aspiringblu check` you can call the Zone Checker to find out what spells are left in the area that you have not yet learned.
- Wide Scan Filter: Using the command `//aspblu filter` or `//aspiringblu filter` will enable filtering on Wide Scan to only show mobs you can learn spells from.
- Alerts: Using the command `//aspblu alert` or `//aspiringblu alert` will periodically send a chat alert if a mob that you can learn a spell from is nearby.
- New Blue Magic Used: When a mob uses a spell you have not learned, it will play a text to speech sound and become targetable by using the command `//aspblu target` or `//aspiringblu target`. This will help if you are farming them in groups.
- New Blue Magic Learned: Once you have learned a new spell a text to speech sound will play to verify you have learned the spell and not missed it in the swarm of RoE text.
- Main Job Check: If you do not have BLU as your main job then all functions will be disabled.

## Installation
To install aspiringBlu, follow these steps:

1. Clone the repository:
    ```sh
    git clone git@github.com:roxasunbanned/aspiringBLU.git
    ```
2. Move the Project files into your Windower addons folder

## Usage
To use aspiringBlu, you may have to manually load with `lua load aspiringblu`