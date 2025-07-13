-- enemy_blueprints.lua
-- Defines the data-driven blueprints for all enemy types.

local EnemyBlueprints = {
    brawler = {
        color = {0.7, 0.7, 0.7},
        maxHp = 140,
        attackStat = 60,
        defenseStat = 50,
        movement = 5,
        attacks = {
            {name = "standard_melee", power = 20, cost = 3, attack_style = "melee"}
        },
        moveDelay = 3.0
    },
    archer = {
        color = {0.7, 0.7, 0.7},
        maxHp = 110,
        attackStat = 50,
        defenseStat = 40,
        movement = 4,
        attacks = {
            {name = "archer_shot", power = 10, cost = 2, attack_style = "ranged"},
            {name = "archer_barrage", power = 5, cost = 4, attack_style = "ranged"} -- New attack
        },
        moveDelay = 3.0
    },
    punter = {
        color = {0.7, 0.7, 0.7},
        maxHp = 120,
        attackStat = 50,
        defenseStat = 40,
        movement = 5,
        attacks = {
            {name = "punter_spin", power = 15, cost = 3, attack_style = "melee"}
        },
        moveDelay = 3.0
    }
}

return EnemyBlueprints