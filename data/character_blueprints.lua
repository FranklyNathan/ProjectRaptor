-- character_blueprints.lua
-- Defines the data-driven blueprints for all player types.
-- The 'attacks' table now contains string identifiers for attack functions,
-- which are implemented in player_attacks.lua.

local CharacterBlueprints = {
    drapionsquare = {
        displayName = "Drapion",
        maxHp = 120,
        attackStat = 50,
        defenseStat = 50,
        passive = "drapion_action_on_kill",
        movement = 7,
        dominantColor = {0.5, 0.2, 0.8}, -- Drapion: Purple
        attacks = {
            j = {name = "drapion_j", power = 40, cost = 2, type = "damage", attack_style = "melee"},
            k = {name = "drapion_k", power = 20, cost = 2, type = "damage", attack_style = "melee"},
            l = {name = "drapion_l", power = 40, cost = 4, type = "damage", attack_style = "melee"},
        }
    },
    florgessquare = {
        displayName = "Florges",
        maxHp = 100,
        attackStat = 40,
        defenseStat = 50,
        passive = "florges_regen",
        movement = 5,
        dominantColor = {1.0, 0.6, 0.8}, -- Florges: Light Florges
        attacks = {
            j = {name = "florges_j", power = 20, cost = 2, type = "damage", attack_style = "melee"},
            k = {name = "florges_k", power = 40, cost = 5, type = "support", attack_style = "melee"}, -- Power here represents heal amount
            l = {name = "florges_l", power = 0, cost = 2, type = "support", attack_style = "melee"},
        }
    },
    venusaursquare = {
        displayName = "Venusaur",
        maxHp = 60,
        attackStat = 60,
        defenseStat = 50,
        passive = "venusaur_crit_bonus",
        movement = 5,
        dominantColor = {0.6, 0.9, 0.6}, -- Venusaur: Pale Green
        attacks = {
            j = {name = "venusaur_j", power = 20, cost = 1, type = "damage", attack_style = "ranged"},
            k = {name = "venusaur_k", power = 20, cost = 2, type = "damage", attack_style = "ranged"},
            l = {name = "venusaur_l", power = 0, cost = 3, type = "support", attack_style = "ranged"},
        }
    },
    magnezonesquare = {
        displayName = "Magnezone",
        maxHp = 80,
        attackStat = 50,
        defenseStat = 50,
        movement = 4,
        dominantColor = {0.6, 0.6, 0.7}, -- Magnezone: Steel Grey
        -- No team-wide passive, but has unique attack mechanics
        attacks = {
            j = {name = "magnezone_j", power = 30, cost = 3, type = "damage", attack_style = "melee"},
            k = {name = "magnezone_k", power = 0, cost = 2, type = "support", attack_style = "melee"},
            l = {name = "magnezone_l", power = 0, cost = 2, type = "support", attack_style = "melee"},
        }
    },
    electiviresquare = {
        displayName = "Electivire",
        maxHp = 100,
        attackStat = 50,
        defenseStat = 50,
        passive = "electivire_comet_damage",
        movement = 6,
        dominantColor = {1.0, 0.8, 0.1}, -- Electivire: Electric Venusaur
        attacks = {
            j = {name = "electivire_j", power = 20, cost = 5, type = "damage", attack_style = "ranged"}, -- Continuous attack, power is per hit
            k = {name = "electivire_k", power = 40, cost = 2, type = "damage", attack_style = "ranged"},
            l = {name = "electivire_l", power = 0, cost = 1, type = "support", attack_style = "melee"},
        }
    },
    tangrowthsquare = {
        displayName = "Tangrowth",
        maxHp = 101,
        attackStat = 50,
        defenseStat = 50,
        passive = "tangrowth_careen_double",
        movement = 4,
        dominantColor = {0.1, 0.3, 0.8}, -- Tangrowth: Dark Blue
        attacks = {
            j = {name = "tangrowth_j", power = 10, cost = 3, type = "damage", attack_style = "ranged"}, -- Grappling Hook
            k = {name = "tangrowth_k", power = 0, cost = 4, type = "support", attack_style = "ranged"}, -- Team Shield
            l = {name = "tangrowth_l", power = 10, cost = 5, type = "damage", attack_style = "ranged"}, -- Mass Grapple
        }
    },
    sceptilesquare = {
        displayName = "Sceptile",
        maxHp = 110,
        attackStat = 50,
        defenseStat = 50,
        passive = "sceptile_speed_boost",
        movement = 8,
        dominantColor = {0.1, 0.8, 0.3}, -- Sceptile: Leaf Green
        attacks = {
            j = {name = "sceptile_j", power = 10, cost = 1, type = "utility", attack_style = "ranged"}, -- Plant Flag
            k = {name = "sceptile_k", power = 30, cost = 4, type = "damage", attack_style = "melee"},  -- Dash to Flag
            l = {name = "sceptile_l", power = 0, cost = 3, type = "support", attack_style = "ranged"}, -- Zone Shield
        }
    },
    pidgeotsquare = {
        displayName = "Pidgeot",
        maxHp = 90,
        attackStat = 50,
        defenseStat = 50,
        passive = "pidgeot_passive_placeholder", -- To be implemented
        movement = 9,
        isFlying = true,
        dominantColor = {0.8, 0.7, 0.4}, -- Pidgeot: Sandy Brown
        attacks = {
            j = {name = "pidgeot_j", power = 0, cost = 1, type = "utility", attack_style = "melee"}, -- Quick Attack
            k = {name = "pidgeot_k", power = 15, cost = 2, type = "damage", attack_style = "melee"}, -- Gust
            l = {name = "pidgeot_l", power = 20, cost = 1, type = "damage", attack_style = "melee"},  -- Multi-hit warp attack
        }
    }
}

return CharacterBlueprints