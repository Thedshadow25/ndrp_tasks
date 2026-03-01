# NDRP Tasks - FiveM Task System

A comprehensive, production-ready FiveM job system featuring multiple task types, player progression, and a complete UI.

## Features

### Task Types
- **Deliveries** (Easy) - Pick up and deliver items around the city
- **Material Collection** (Medium) - Search areas and gather materials
- **Vehicle Theft** (Hard) - Steal vehicles with NPC guards
- **Smuggling** (Expert) - Transport cargo without being stopped

### Progression System
- **XP & Levels** - Earn XP for completing tasks and progress through levels
- **Stats Tracking** - Track missions completed and total earnings
- **Level Requirements** - Advanced tasks require higher player levels
- **Cooldown System** - Players must wait between missions

### Game Features
- **Animated Delivery Props** - Carry boxes realistically
- **Vehicle Trunks** - Store items in vehicle trunks
- **NPC Interactions** - Talk to NPCs for deliveries and trades
- **Damage Penalties** - Vehicle condition affects rewards
- **Progress Timeline** - Track mission progress visually
- **GPS Integration** - Waypoint navigation for all tasks

## Installation

### Requirements
- [ox_lib](https://github.com/overextended/ox_lib)
- [ox_target](https://github.com/overextended/ox_target)
- [ox_inventory](https://github.com/overextended/ox_inventory)
- [lation_ui](https://github.com/lation-code/lation_ui)
- QBX Core Framework

### Setup
1. Clone the resource to your `resources` folder
2. Ensure all dependencies are started before this script
3. Add to your `server.cfg`:
   ```
   ensure ndrp_tasks
   ```

## Configuration

Edit `config.lua` to customize:
- Task station location and appearance
- Reward amounts for each mission
- XP requirements for level progression
- Task locations and delivery zones
- NPC models and weapons
- Animation settings

## Commands

### Player Commands
- `/cancel` - Abandon current mission (applies cooldown)

### Debug Commands (commented out)
Uncomment in `client/main.lua` to enable:
- `/testnui` - Open task menu
- `/closenui` - Close task menu

## Production Improvements

### Error Handling
- Input validation on all server callbacks
- Nil checks in critical functions
- Entity existence validation
- Proper logging for debugging

### Security
- Server-side mission enforcement
- License-based player data storage
- Cooldown validation on server
- Level requirement checks

### Data Persistence
- Player XP and levels saved to KVP
- Mission statistics tracked
- Cooldown management
- Automatic cleanup on player disconnect

## File Structure

```
ndrp_tasks/
├── config.lua           # Configuration for all tasks and rewards
├── client/main.lua      # Client-side logic and UI handlers
├── server/main.lua      # Server-side logic, data, and security
├── ui.html             # Task selection UI
├── web/
│   ├── index.html      # Secondary UI
│   ├── script.js       # UI scripting
│   └── style.css       # UI styling
├── fxmanifest.lua      # Resource manifest
└── README.md           # This file
```

## Customization

### Add New Tasks
1. Add a new category object to `Config.Categories` in `config.lua`
2. Define missions with appropriate reward amounts
3. Set location coordinates and NPC models
4. Configure progress bar messages and animations

### Adjust Rewards
Edit the `reward` values in each mission definition or use the range format:
- `reward = 500` - Fixed amount
- `reward = '400-600'` - Range (display only)

### Change Difficulty Levels
Edit `difficulty` and `requiredLevel` in category definitions

## Support & Issues

For bugs or feature requests, ensure:
1. All dependencies are properly installed
2. Frame rate is adequate (60+ FPS recommended)
3. No console errors on startup
4. Script is compatible with your server framework

## License

Production-ready version. All Swedish text translated to English.
