Config = {}

-- ===================================================
-- TASK STATION (Task Station Ped)
-- ===================================================
Config.Station = {
    coords = vector4(-97.18, -1013.77, 26.28, 156.77),
    pedModel = 'a_m_y_business_03',
    blip = {
        sprite = 478,
        color = 3,
        scale = 0.85,
        label = 'Task Center',
    },
    interactLabel = 'View available tasks',
    interactIcon = 'fas fa-clipboard-list',
}

-- ===================================================
-- COOLDOWN (seconds)
-- ===================================================
Config.Cooldown = 600  -- 10 minutes

-- ===================================================
-- XP / LEVEL SYSTEM
-- ===================================================
Config.Levels = {
    { level = 1, xpRequired = 0,   label = 'Beginner' },
    { level = 2, xpRequired = 100, label = 'Experienced' },
    { level = 3, xpRequired = 300, label = 'Veteran' },
}

-- ===================================================
-- CATEGORIES
-- ===================================================
Config.Categories = {
    -- ========================
    -- EASY: Deliveries
    -- ========================
    {
        id = 'cat_delivery',
        name = 'Deliveries',
        description = 'Pick up and deliver goods around the city',
        icon = 'fas fa-truck-fast',
        difficulty = 'Easy',
        reward = '450-600',
        xpReward = 10,
        requiredLevel = 1,
        missions = {
            {
                type = 'delivery',
                name = 'Phone Delivery',
                item = 'phone',
                reward = 500,
                dropoff = {
                    coords = vector4(0.57, -159.17, 55.32, 340.99),
                    pedModel = 'a_m_y_business_01',
                    blip = { sprite = 1, color = 2, scale = 0.8, label = 'Dropoff - Phone' },
                },
                progress = {
                    dropoff = {
                        label = 'Delivering phone...',
                        duration = 4000,
                        icon = 'fas fa-box-open',
                        anim = { dict = 'mp_common', clip = 'givetake1_b' },
                        steps = {
                            { description = 'Unpacking delivery...' },
                            { description = '"Thanks, exactly what I was waiting for!"' },
                        },
                    },
                },
            },
            {
                type = 'delivery',
                name = 'Food Delivery',
                item = 'burger',
                reward = 450,
                dropoff = {
                    coords = vector4(-1200.08, -904.67, 12.62, 139.81),
                    pedModel = 'a_f_y_hipster_01',
                    blip = { sprite = 1, color = 2, scale = 0.8, label = 'Dropoff - Food' },
                },
                progress = {
                    dropoff = {
                        label = 'Delivering food...',
                        duration = 3500,
                        icon = 'fas fa-utensils',
                        anim = { dict = 'mp_common', clip = 'givetake1_b' },
                        steps = {
                            { description = 'Handing over food...' },
                            { description = '"Mmm, smells great! Thanks!"' },
                        },
                    },
                },
            },
            {
                type = 'delivery',
                name = 'Medicine Delivery',
                item = 'bandage',
                reward = 600,
                dropoff = {
                    coords = vector4(296.33, -590.98, 42.27, 80.41),
                    pedModel = 'a_m_m_socenlat_01',
                    blip = { sprite = 1, color = 2, scale = 0.8, label = 'Dropoff - Medicine' },
                },
                progress = {
                    dropoff = {
                        label = 'Delivering medicine...',
                        duration = 4500,
                        icon = 'fas fa-briefcase-medical',
                        anim = { dict = 'mp_common', clip = 'givetake1_b' },
                        steps = {
                            { description = 'Checking package...' },
                            { description = '"Thanks! This was really needed."' },
                        },
                    },
                },
            },
            {
                type = 'delivery',
                name = 'Document Courier',
                item = 'tablet',
                reward = 550,
                dropoff = {
                    coords = vector4(-598.87, -933.56, 22.86, 90.08),
                    pedModel = 'a_m_y_business_02',
                    blip = { sprite = 1, color = 2, scale = 0.8, label = 'Dropoff - Documents' },
                },
                progress = {
                    dropoff = {
                        label = 'Delivering documents...',
                        duration = 4000,
                        icon = 'fas fa-file-signature',
                        anim = { dict = 'mp_common', clip = 'givetake1_b' },
                        steps = {
                            { description = 'Handing over documents...' },
                            { description = '"Perfect, right on time."' },
                        },
                    },
                },
            },
        },
    },

    -- ========================
    -- MEDIUM: Material Collection
    -- ========================
    {
        id = 'cat_scavenge',
        name = 'Material Collection',
        description = 'Search areas and collect materials',
        icon = 'fas fa-cubes-stacked',
        difficulty = 'Medium',
        reward = '1400-1800',
        xpReward = 25,
        requiredLevel = 1,
        missions = {
            {
                type = 'scavenge',
                name = 'Metal Collection',
                item = 'metalscrap',
                itemMin = 1,
                itemMax = 12,
                reward = 1500,
                searchArea = {
                    center = vector3(2803.39, -702.14, 2.04),
                    radius = 50.0,
                    blip = { sprite = 1, color = 3, scale = 0.9, label = 'Search Area - Metal' },
                },
                props = {
                    model = 'prop_box_wood05a',
                    locations = {
                        vector4(2820.4, -715.56, 1.45, 302.72),
                        vector4(2826.54, -697.16, 0.78, 339.76),
                        vector4(2815.88, -690.31, 0.51, 41.6),
                        vector4(2809.22, -706.71, 1.61, 154.03),
                    },
                },
                progress = {
                    search = {
                        label = 'Searching box...',
                        duration = 6000,
                        icon = 'fas fa-magnifying-glass',
                        anim = { dict = 'mini@repair', clip = 'fixing_a_ped' },
                        steps = {
                            { description = 'Opening box...' },
                            { description = 'Searching contents...' },
                        },
                    },
                },
            },
            {
                type = 'scavenge',
                name = 'Aluminum Hunt',
                item = 'aluminum',
                itemMin = 2,
                itemMax = 10,
                reward = 1400,
                searchArea = {
                    center = vector3(2332.59, 3135.01, 48.21),
                    radius = 45.0,
                    blip = { sprite = 1, color = 3, scale = 0.9, label = 'Search Area - Aluminum' },
                },
                props = {
                    model = 'prop_box_wood04a',
                    locations = {
                        vector4(2331.44, 3153.17, 47.11, 304.4),
                        vector4(2322.63, 3139.36, 47.16, 135.47),
                        vector4(2326.8, 3126.33, 47.16, 203.85),
                        vector4(2333.68, 3136.0, 47.18, 319.7),
                    },
                },
                progress = {
                    search = {
                        label = 'Searching scrap...',
                        duration = 7000,
                        icon = 'fas fa-wrench',
                        anim = { dict = 'mini@repair', clip = 'fixing_a_ped' },
                        steps = {
                            { description = 'Digging through scrap...' },
                            { description = 'Checking material...' },
                        },
                    },
                },
            },
            {
                type = 'scavenge',
                name = 'Iron Scrap',
                item = 'iron',
                itemMin = 1,
                itemMax = 8,
                reward = 1800,
                searchArea = {
                    center = vector3(-437.09, -2174.60, 10.04),
                    radius = 55.0,
                    blip = { sprite = 1, color = 3, scale = 0.9, label = 'Search Area - Iron Scrap' },
                },
                props = {
                    model = 'prop_box_ammo04a',
                    locations = {
                        vector4(-439.07, -2178.73, 9.32, 225.63),
                        vector4(-444.66, -2179.62, 9.32, 101.83),
                        vector4(-442.59, -2176.07, 9.32, 306.29),
                        vector4(-438.11, -2175.19, 9.33, 271.78),
                    },
                },
                progress = {
                    search = {
                        label = 'Collecting iron scrap...',
                        duration = 5500,
                        icon = 'fas fa-screwdriver-wrench',
                        anim = { dict = 'mini@repair', clip = 'fixing_a_ped' },
                        steps = {
                            { description = 'Breaking loose metal...' },
                            { description = 'Gathering pieces...' },
                        },
                    },
                },
            },
        },
    },

    -- ========================
    -- HARD: Vehicle Theft
    -- ========================
    {
        id = 'cat_cartheft',
        name = 'Vehicle Theft',
        description = 'Steal a vehicle and deliver it - expect resistance',
        icon = 'fas fa-car-burst',
        difficulty = 'Hard',
        reward = '2800-3500',
        xpReward = 50,
        requiredLevel = 1,
        missions = {
            {
                type = 'cartheft',
                name = 'Sultan Theft',
                reward = 3000,
                car = {
                    model = 'sultan',
                    coords = vector4(27.97, 3730.68, 38.21, 44.56),
                    blip = { sprite = 225, color = 1, scale = 0.9, label = 'Target Vehicle' },
                },
                guard = {
                    model = 'g_m_y_lost_02',
                    offset = vector4(24.15, 3737.12, 38.68, 213.87),
                    weapon = 'WEAPON_BAT',
                },
                delivery = {
                    center = vector3(873.48, -2188.96, 29.11),
                    radius = 15.0,
                    blip = { sprite = 473, color = 5, scale = 0.9, label = 'Delivery - Vehicle' },
                },
            },
            {
                type = 'cartheft',
                name = 'Luxury SUV Theft',
                reward = 3500,
                car = {
                    model = 'baller7',
                    coords = vector4(-1533.58, 134.18, 55.65, 228.0),
                    blip = { sprite = 225, color = 1, scale = 0.9, label = 'Target SUV' },
                },
                guard = {
                    model = 'g_m_m_armgoon_01',
                    offset = vector4(-1530.20, 137.40, 55.65, 50.0),
                    weapon = 'WEAPON_KNIFE',
                },
                delivery = {
                    center = vector3(538.02, -182.76, 54.49),
                    radius = 15.0,
                    blip = { sprite = 473, color = 5, scale = 0.9, label = 'Delivery - Vehicle' },
                },
            },
            {
                type = 'cartheft',
                name = 'Motorcycle Theft',
                reward = 2800,
                car = {
                    model = 'hexer',
                    coords = vector4(1987.21, 3783.64, 32.18, 30.0),
                    blip = { sprite = 226, color = 1, scale = 0.9, label = 'Target Motorcycle' },
                },
                guard = {
                    model = 'g_m_y_lost_01',
                    offset = vector4(1989.62, 3780.94, 31.18, 73.78),
                    weapon = 'WEAPON_CROWBAR',
                },
                delivery = {
                    center = vector3(873.48, -2188.96, 29.11),
                    radius = 15.0,
                    blip = { sprite = 473, color = 5, scale = 0.9, label = 'Delivery - Vehicle' },
                },
            },
        },
    },

    -- ========================
    -- EXPERT: Smuggling (Level 2)
    -- ========================
    {
        id = 'cat_smuggle',
        name = 'Smuggling',
        description = 'Transport cargo without being stopped',
        icon = 'fas fa-vault',
        difficulty = 'Expert',
        reward = '4000-5000',
        xpReward = 75,
        requiredLevel = 2,
        missions = {
            {
                type = 'smuggle',
                name = 'Weapon Delivery',
                reward = 4500,
                vehicle = {
                    model = 'speedo',
                    coords = vector4(365.88, 3411.47, 35.14, 22.88),
                    blip = { sprite = 67, color = 1, scale = 0.9, label = 'Smuggler Vehicle' },
                },
                delivery = {
                    coords = vector4(1242.26, -3234.0, 5.03, 345.21),
                    pedModel = 'g_m_y_mexgoon_01',
                    radius = 15.0,
                    blip = { sprite = 473, color = 46, scale = 0.9, label = 'Delivery - Cargo' },
                },
                progress = {
                    dropoff = {
                        label = 'Unloading cargo...',
                        duration = 8000,
                        icon = 'fas fa-boxes-packing',
                        anim = { dict = 'anim@heists@box_carry@', clip = 'idle' },
                        steps = {
                            { description = 'Carrying cargo to buyer...' },
                            { description = '"Good job. No questions."' },
                            { description = 'Receiving payment...' },
                        },
                    },
                },
            },
            {
                type = 'smuggle',
                name = 'Electronics Smuggling',
                reward = 4000,
                vehicle = {
                    model = 'rumpo',
                    coords = vector4(1374.18, 3614.96, 33.91, 200.52),
                    blip = { sprite = 67, color = 1, scale = 0.9, label = 'Smuggler Vehicle' },
                },
                delivery = {
                    coords = vector4(-1147.67, -2039.0, 12.16, 143.83),
                    pedModel = 'g_m_y_salvagoon_01',
                    radius = 15.0,
                    blip = { sprite = 473, color = 46, scale = 0.9, label = 'Delivery - Electronics' },
                },
                progress = {
                    dropoff = {
                        label = 'Handing over goods...',
                        duration = 7000,
                        icon = 'fas fa-microchip',
                        anim = { dict = 'anim@heists@box_carry@', clip = 'idle' },
                        steps = {
                            { description = 'Unloading electronics...' },
                            { description = '"Quality stuff. Paid."' },
                        },
                    },
                },
            },
            {
                type = 'smuggle',
                name = 'Luxury Smuggling',
                reward = 5000,
                vehicle = {
                    model = 'youga2',
                    coords = vector4(2548.8, 342.95, 107.43, 265.26),
                    blip = { sprite = 67, color = 1, scale = 0.9, label = 'Smuggler Vehicle' },
                },
                delivery = {
                    coords = vector4(-41.11, -1747.84, 28.33, 318.67),
                    pedModel = 'a_m_y_business_03',
                    radius = 15.0,
                    blip = { sprite = 473, color = 46, scale = 0.9, label = 'Delivery - Luxury Items' },
                },
                progress = {
                    dropoff = {
                        label = 'Handing over luxury goods...',
                        duration = 9000,
                        icon = 'fas fa-gem',
                        anim = { dict = 'anim@heists@box_carry@', clip = 'idle' },
                        steps = {
                            { description = 'Carrying boxes carefully...' },
                            { description = '"Be careful, this is expensive."' },
                            { description = '"Perfect. Money is in the envelope."' },
                        },
                    },
                },
            },
        },
    },
}

-- ===================================================
-- LATION TIMELINE SETTINGS
-- ===================================================
Config.Timeline = {
    position = 'right-center',
    icon = 'fas fa-truck',
    iconColor = '#3B82F6',
    opacity = 0.9,
}

-- ===================================================
-- DELIVERY PROP (attached to player while carrying)
-- ===================================================
Config.DeliveryProp = {
    model = 'prop_cs_cardbox_01',
    bone = 28422, -- Right Hand (positions box centrally for two-handed carry anim)
    pos = { x = 0.0, y = -0.03, z = 0.0 },
    rot = { x = 5.0, y = 0.0, z = 0.0 },
}
