#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../lib/kumi"

module DamageCalculation
  extend Kumi::Schema

  schema do
    input do
      # Base combat stats
      integer :base_attack, domain: 0..500
      integer :strength, domain: 0..100
      integer :level, domain: 1..100
      
      # Equipment bonuses
      integer :weapon_damage, domain: 0..100
      integer :weapon_bonus, domain: 0..50
      string  :weapon_type, domain: %w[sword dagger staff bow fists]
      
      # Combat modifiers
      boolean :critical_hit
      string  :attack_type, domain: %w[normal magic special]
      array   :abilities, elem: { type: :string }
      array   :status_effects, elem: { type: :string }
      
      # Status effect turn counters
      integer :rage_turns, domain: 0..10
      integer :poison_turns, domain: 0..10
      integer :blessing_turns, domain: 0..10
    end

    # Combat traits
    trait :is_critical, (input.critical_hit == true)
    trait :is_magic_attack, (input.attack_type == "magic")
    trait :is_special_attack, (input.attack_type == "special")
    trait :has_rage, fn(:include?, input.status_effects, "rage")
    trait :has_blessing, fn(:include?, input.status_effects, "blessing")
    trait :is_poisoned, fn(:include?, input.status_effects, "poison")
    trait :has_precision, fn(:include?, input.abilities, "precision")
    trait :critical_precision, is_critical & has_precision

    # Weapon type traits
    trait :melee_weapon, fn(:include?, ["sword", "dagger"], input.weapon_type)
    trait :ranged_weapon, (input.weapon_type == "bow")
    trait :magic_weapon, (input.weapon_type == "staff")

    # Strength traits
    trait :high_strength, (input.strength >= 15)

    # Base damage calculation
    value :strength_bonus do
      on high_strength, input.strength * 2  # NEW: bare identifier syntax
      base input.strength
    end

    value :weapon_total_damage, (input.weapon_damage + input.weapon_bonus)

    value :base_damage_value, (input.base_attack + strength_bonus + weapon_total_damage)

    # Status effect modifiers
    value :status_attack_multiplier do
      on has_rage, 1.5      # NEW: bare identifier syntax
      on is_poisoned, 0.8   # NEW: bare identifier syntax
      on has_blessing, 1.1  # NEW: bare identifier syntax
      base 1.0
    end

    # Critical and special attack modifiers
    value :attack_type_multiplier do
      on critical_precision, 3.0  # NEW: bare identifier syntax
      on is_critical, 2.0          # NEW: bare identifier syntax
      on is_special_attack, 1.3    # NEW: bare identifier syntax
      on is_magic_attack, 1.2      # NEW: bare identifier syntax
      base 1.0
    end

    # Level scaling
    value :level_bonus, (input.level / 3)

    # Final damage calculation
    value :total_damage, fn(:round, (base_damage_value + level_bonus) * status_attack_multiplier * attack_type_multiplier)

    # Damage description for UI
    value :damage_description do
      on critical_precision, "💥🎯 PRECISION CRITICAL!"  # NEW: bare identifier syntax
      on is_critical, "💥 CRITICAL HIT!"                 # NEW: bare identifier syntax
      on is_special_attack, "✨ Special Attack!"         # NEW: bare identifier syntax
      on is_magic_attack, "🔮 Magic Attack!"             # NEW: bare identifier syntax
      base "⚔️ Attack!"
    end
  end
end

module DamageReduction
  extend Kumi::Schema

  schema do
    input do
      # Base defensive stats
      integer :base_defense, domain: 0..300
      integer :defense_stat, domain: 0..100
      integer :agility, domain: 0..100
      integer :level, domain: 1..100
      
      # Equipment bonuses
      integer :armor_defense, domain: 0..50
      integer :armor_bonus, domain: 0..30
      string  :armor_type, domain: %w[leather chainmail plate robe none]
      
      # Incoming damage info
      integer :incoming_damage, domain: 0..1000
      string  :damage_type, domain: %w[normal magic special]
      
      # Status effects
      array   :status_effects, elem: { type: :string }
      integer :shield_turns, domain: 0..10
      integer :blessing_turns, domain: 0..10
      integer :poison_turns, domain: 0..10
    end

    # Defensive traits
    trait :has_shield, fn(:include?, input.status_effects, "shield")
    trait :has_blessing, fn(:include?, input.status_effects, "blessing")
    trait :is_poisoned, fn(:include?, input.status_effects, "poison")
    trait :taking_magic_damage, (input.damage_type == "magic")
    trait :taking_special_damage, (input.damage_type == "special")
    trait :high_agility, (input.agility >= 15)
    trait :heavy_armor, fn(:include?, ["chainmail", "plate"], input.armor_type)
    trait :light_armor, fn(:include?, ["leather", "robe"], input.armor_type)

    # Defense traits
    trait :high_defense, (input.defense_stat >= 15)
    
    # Composite armor/damage type traits
    trait :heavy_vs_magic, heavy_armor & taking_magic_damage
    trait :light_vs_magic, light_armor & taking_magic_damage

    # Base defense calculation
    value :defense_bonus do
      on high_defense, (input.defense_stat * 1.5)  # NEW: bare identifier syntax
      base input.defense_stat
    end

    value :equipment_defense, (input.armor_defense + input.armor_bonus)

    value :level_defense_bonus, (input.level / 2)

    value :base_defense_value, (input.base_defense + defense_bonus + equipment_defense + level_defense_bonus)

    # Status effect defensive modifiers
    value :status_defense_multiplier do
      on has_shield, 1.4    # NEW: bare identifier syntax
      on has_blessing, 1.2  # NEW: bare identifier syntax  
      on is_poisoned, 0.9   # NEW: bare identifier syntax
      base 1.0
    end

    # Armor type resistances
    value :armor_resistance do
      on heavy_vs_magic, 0.8  # Heavy armor weak to magic
      on light_vs_magic, 1.1  # Light armor resists magic
      on heavy_armor, 1.2  # Heavy armor good vs physical
      on light_armor, 0.9  # Light armor weak vs physical
      base 1.0
    end

    # Calculate total defense
    value :total_defense, fn(:round, base_defense_value * status_defense_multiplier * armor_resistance)

    # Dodge calculation
    value :dodge_chance do
      on high_agility, fn(:min, [(input.agility * 0.05), 0.3])
      base fn(:min, [(input.agility * 0.02), 0.15])
    end

    # Final damage after reduction
    value :damage_after_defense, fn(:max, [(input.incoming_damage - total_defense), 1])

    # Defense description for UI
    value :defense_description do
      on has_shield, "🛡️ Shield Active!"
      on heavy_armor, "⚔️ Heavy Armor Protection"
      on light_armor, "🏃 Light Armor Agility"
      base "🛡️ Defending"
    end
  end
end

module Equipment
  extend Kumi::Schema

  schema do
    input do
      string  :weapon_name
      string  :weapon_type, domain: %w[sword dagger staff bow fists]
      integer :weapon_damage, domain: 0..50
      string  :armor_name
      string  :armor_type, domain: %w[leather chainmail plate robe none]
      integer :armor_defense, domain: 0..30
      string  :accessory_name
      string  :accessory_type, domain: %w[ring amulet boots gloves none]
      integer :accessory_bonus, domain: 0..20
    end

    trait :has_weapon, (input.weapon_type != "fists")
    trait :has_armor, (input.armor_type != "none")
    trait :has_accessory, (input.accessory_type != "none")
    trait :melee_weapon, fn(:include?, ["sword", "dagger"], input.weapon_type)
    trait :ranged_weapon, (input.weapon_type == "bow")
    trait :magic_weapon, (input.weapon_type == "staff")
    trait :heavy_armor, fn(:include?, ["chainmail", "plate"], input.armor_type)
    trait :light_armor, fn(:include?, ["leather", "robe"], input.armor_type)

    value :total_weapon_damage do
      on ranged_weapon, (input.weapon_damage + 4)
      on magic_weapon, (input.weapon_damage + 3)
      on has_weapon, (input.weapon_damage + 2)
      base 2
    end

    value :total_armor_defense do
      on has_armor, (input.armor_defense + 1)
      base 0
    end

    value :equipment_agility_modifier do
      on heavy_armor, -2
      on light_armor, 1
      base 0
    end

    value :equipment_strength_modifier do
      on melee_weapon, 2
      base 0
    end

    value :equipment_description do
      on has_weapon,has_armor,has_accessory, fn(:concat, [input.weapon_name, ", ", input.armor_name, ", ", input.accessory_name])
      on has_weapon,has_armor, fn(:concat, [input.weapon_name, ", ", input.armor_name])
      on has_weapon, fn(:concat, [input.weapon_name, " (Unarmored)"])
      base "Basic gear"
    end
  end
end

module PlayerEntity
  extend Kumi::Schema

  schema do
    input do
      string  :name
      integer :level, domain: 1..100
      integer :health, domain: 0..1000
      integer :max_health, domain: 1..1000
      integer :mana, domain: 0..500
      integer :max_mana, domain: 0..500
      integer :strength, domain: 1..100
      integer :defense, domain: 1..100
      integer :agility, domain: 1..100
      integer :experience, domain: 0..Float::INFINITY
      string  :weapon, domain: %w[sword dagger staff bow fists]
      array   :inventory, elem: { type: :string }
      hash    :stats, key: { type: :string }, val: { type: :integer }
      hash    :equipment, key: { type: :string }, val: { type: :any }
      array   :status_effects, elem: { type: :string }
      integer :poison_turns, domain: 0..10
      integer :blessing_turns, domain: 0..10
      integer :rage_turns, domain: 0..5
      integer :shield_turns, domain: 0..5
    end

    trait :alive, (input.health > 0)
    trait :dead, (input.health <= 0)
    trait :low_health, (input.health <= input.max_health * 0.3) & alive
    trait :full_health, (input.health == input.max_health)
    trait :has_mana, (input.mana > 0)
    trait :low_mana, (input.mana <= input.max_mana * 0.2)
    trait :strong, (input.strength >= 15)
    trait :agile, (input.agility >= 15)
    trait :tanky, (input.defense >= 15)
    trait :experienced, (input.level >= 5)
    trait :has_sword, (input.weapon == "sword")
    trait :has_dagger, (input.weapon == "dagger")
    trait :has_staff, (input.weapon == "staff")
    trait :has_bow, (input.weapon == "bow")
    trait :well_equipped, fn(:include?, input.inventory, "upgrade_token")
    trait :has_potions, fn(:include?, input.inventory, "potion")
    trait :has_status_effects, (fn(:size, input.status_effects) > 0)

    value :health_percentage, ((input.health * 100) / input.max_health)
    value :mana_percentage, ((input.mana * 100) / input.max_mana)
    
    # Basic combat stats (for UI display)
    value :base_weapon_bonus do
      on has_sword, 8
      on has_dagger, 5
      on has_staff, 3
      on has_bow, 6
      base 2
    end

    value :equipment_defense_bonus do
      on well_equipped, 2
      base 0
    end

    # Simplified values for UI - actual combat will use the damage schemas
    value :total_attack, (15 + input.strength + fn(:fetch, input.equipment, "weapon_damage", 12) + base_weapon_bonus)
    value :defense_rating, (10 + input.defense + fn(:fetch, input.equipment, "armor_defense", 5) + (input.level / 2))
    value :dodge_chance do
      on agile, fn(:min, [(input.agility * 0.05), 0.3])
      base fn(:min, [(input.agility * 0.02), 0.15])
    end

    value :health_status_description do
      on dead, "💀 Dead"
      on low_health, "⚠️ Critically wounded"
      on full_health, "💚 Perfect condition"
      base "🩹 Injured"
    end

    value :status_description, health_status_description

    value :can_level_up, (input.experience >= (input.level * 100))
    value :next_level_exp, (input.level * 100)
  end
end

module Enemy
  extend Kumi::Schema

  schema do
    input do
      string  :name
      string  :type, domain: %w[goblin orc troll dragon skeleton mage]
      integer :level, domain: 1..50
      integer :health, domain: 0..2000
      integer :max_health, domain: 1..2000
      integer :attack, domain: 1..200
      integer :defense, domain: 1..100
      float   :dodge_chance, domain: 0.0..0.5
      array   :abilities, elem: { type: :string }
      hash    :loot_table, key: { type: :string }, val: { type: :integer }
    end

    trait :alive, (input.health > 0)
    trait :dead, (input.health <= 0)
    trait :boss, (input.type == "dragon")
    trait :weak, (input.health <= input.max_health * 0.25)
    trait :dangerous, (input.attack >= 50)
    trait :agile_enemy, (input.dodge_chance >= 0.2)

    value :threat_level do
      on boss, "💀 BOSS"
      on dangerous, "⚡ Dangerous"
      on weak, "🩹 Weakened"
      base "⚔️ Normal"
    end

    value :experience_reward, ((input.level * 25) + (fn(:size, input.abilities) * 10))
    
    value :gold_reward do
      on boss, ((input.level * 50) + 200)
      on dangerous, ((input.level * 30) + 50)
      base ((input.level * 20) + 10)
    end

    # Basic combat stats for UI - actual combat will use damage schemas
    value :attack_damage, (input.attack + (input.level / 2))
    value :defense_rating, (input.defense + (input.level / 3))
  end
end

module CombatCalculation
  extend Kumi::Schema

  schema do
    input do
      integer :attacker_attack, domain: 0..500
      integer :defender_defense, domain: 0..300
      float   :defender_dodge, domain: 0.0..1.0
      boolean :critical_hit
      string  :attack_type, domain: %w[normal magic special]
      array   :attacker_abilities, elem: { type: :string }
      integer :attacker_level, domain: 1..100
    end

    trait :hit_connects, (0.5 > input.defender_dodge)
    trait :is_critical, (input.critical_hit == true)
    trait :is_magic, (input.attack_type == "magic")
    trait :is_special, (input.attack_type == "special")
    trait :has_rage, fn(:include?, input.attacker_abilities, "rage")
    trait :has_precision, fn(:include?, input.attacker_abilities, "precision")
    trait :critical_precision, is_critical & has_precision

    value :base_damage, fn(:max, [(input.attacker_attack - input.defender_defense), 1])
    
    value :damage_multiplier do
      on critical_precision, 3.0
      on is_critical, 2.0
      on has_rage, 1.5
      on is_special, 1.3
      base 1.0
    end

    value :final_damage do
      on hit_connects, fn(:round, (base_damage * damage_multiplier))
      base 0
    end

    trait :critical_hit_connects, hit_connects & is_critical
    trait :special_hit_connects, hit_connects & is_special
    
    value :attack_result do
      on critical_hit_connects, "💥 CRITICAL HIT!"
      on special_hit_connects, "✨ Special Attack!"
      on hit_connects, "⚔️ Hit!"
      base "💨 Miss!"
    end
  end
end

module GameState
  extend Kumi::Schema

  schema do
    input do
      integer :turn, domain: 1..Float::INFINITY
      string  :phase, domain: %w[exploration combat victory defeat menu]
      boolean :player_alive
      boolean :enemy_alive
      array   :combat_log, elem: { type: :string }
      hash    :flags, key: { type: :string }, val: { type: :boolean }
      integer :enemies_defeated, domain: 0..Float::INFINITY
      integer :gold, domain: 0..Float::INFINITY
    end

    trait :in_combat, (input.phase == "combat")
    trait :exploring, (input.phase == "exploration")
    trait :game_over, (input.phase == "defeat")
    trait :victorious, (input.phase == "victory")
    trait :both_alive, input.player_alive & input.enemy_alive
    trait :combat_ongoing, in_combat & both_alive

    value :turn_description do
      on game_over, "💀 GAME OVER"
      on victorious, "🎉 VICTORY!"
      on combat_ongoing, "⚔️ Combat"
      on exploring, "🗺️ Exploring..."
      base "📋 Main Menu"
    end

    value :can_flee, in_combat & input.player_alive
    value :can_attack, combat_ongoing
    value :can_explore, exploring & input.player_alive

    value :progress_score, ((input.enemies_defeated * 100) + input.gold)
  end
end

class SimpleGame
  def initialize
    @player_data = {
      name: "Hero",
      level: 1,
      health: 100,
      max_health: 100,
      mana: 50,
      max_mana: 50,
      strength: 12,
      defense: 10,
      agility: 8,
      experience: 0,
      weapon: "sword",
      inventory: ["potion", "bread"],
      stats: { "kills" => 0, "damage_dealt" => 0 },
      equipment: {
        "weapon_name" => "Iron Sword",
        "weapon_type" => "sword",
        "weapon_damage" => 12,
        "armor_name" => "Leather Vest",
        "armor_type" => "leather",
        "armor_defense" => 5,
        "accessory_name" => "none",
        "accessory_type" => "none",
        "accessory_bonus" => 0
      },
      status_effects: [],
      poison_turns: 0,
      blessing_turns: 0,
      rage_turns: 0,
      shield_turns: 0
    }

    @game_state = {
      turn: 1,
      phase: "menu",
      player_alive: true,
      enemy_alive: false,
      combat_log: [],
      flags: { "first_combat" => true },
      enemies_defeated: 0,
      gold: 50
    }

    @current_enemy = nil
  end

  def start
    puts "🎮 Welcome to Kumi RPG!"
    puts "=" * 40
    
    loop do
      display_status
      handle_phase
      break if @game_state[:phase] == "defeat"
    end
  end

  private

  def display_status
    puts "==" * 20

    player = PlayerEntity.from(@player_data)
    game = GameState.from(@game_state)
    
    puts "\n#{game[:turn_description]}"
    puts "Player: #{@player_data[:name]} (Lvl #{@player_data[:level]}) #{player[:status_description]}"
    puts "Health: #{@player_data[:health]}/#{@player_data[:max_health]} (#{player[:health_percentage].round(1)}%)"
    puts "Attack: #{player[:total_attack]} | Defense: #{player[:defense_rating].round(1)}"
    puts "Equipment: #{get_equipment_display}"
    puts "Gold: #{@game_state[:gold]} | Score: #{game[:progress_score]}"
    
    if @current_enemy
      enemy = Enemy.from(@current_enemy)
      puts "\nCurrent Enemy:"
      puts "Enemy: #{@current_enemy[:name]} (Lvl #{@current_enemy[:level]}) #{enemy[:threat_level]}"
      puts "Enemy Health: #{@current_enemy[:health]}/#{@current_enemy[:max_health]}"
    end
  end

  def handle_phase
    case @game_state[:phase]
    when "menu"
      handle_menu
    when "exploration"
      handle_exploration
    when "combat"
      handle_combat
    when "victory"
      handle_victory
    when "defeat"
      puts "💀 Game Over! Final Score: #{GameState.from(@game_state)[:progress_score]}"
    end
  end

  def handle_menu
    puts "\nChoose action:"
    puts "1. Start exploring"
    puts "2. View character"
    puts "3. Manage equipment"
    puts "4. Quit"
    
    action = simulate_user_input(["1", "2", "3", "4"])
    
    case action
    when "1"
      @game_state[:phase] = "exploration"
    when "2"
      show_character_details
    when "3"
      manage_equipment
    when "4"
      @game_state[:phase] = "defeat"
    end
  end

  def handle_exploration
    puts "\nExploring the dungeon..."
    puts "You venture deeper into the dark corridors..."
    
    if rand < 0.7
      encounter_enemy
      # Don't return to menu - stay in combat!
    else
      find_treasure
      puts "\n[ACTION COMPLETE - Returning to menu...]"
      sleep(1)
      @game_state[:phase] = "menu"
    end
  end

  def encounter_enemy
    enemy_types = [
      { name: "Goblin Scout", type: "goblin", level: rand(1..3), health: 30, max_health: 30, attack: 8, defense: 3, dodge_chance: 0.1, abilities: [], loot_table: { "gold" => 15 } },
      { name: "Orc Warrior", type: "orc", level: rand(2..5), health: 60, max_health: 60, attack: 15, defense: 8, dodge_chance: 0.05, abilities: ["rage"], loot_table: { "gold" => 30 } },
      { name: "Skeleton Mage", type: "skeleton", level: rand(3..6), health: 40, max_health: 40, attack: 20, defense: 5, dodge_chance: 0.15, abilities: ["magic_missile"], loot_table: { "gold" => 25 } }
    ]
    
    @current_enemy = enemy_types.sample
    @current_enemy[:health] = @current_enemy[:max_health]
    @game_state[:phase] = "combat"
    @game_state[:enemy_alive] = true
    
    puts "💀 You encounter a #{@current_enemy[:name]}!"
    puts "\n[Press Enter to enter combat]"
    simulate_user_input([""]) 
  end

  def find_treasure
    if rand < 0.3 && !@player_data[:inventory].include?("upgrade_token")
      # Found equipment upgrade
      @player_data[:inventory] << "upgrade_token"
      puts "✨ You found an upgrade token! Visit equipment menu to enhance your gear."
    else
      # Found gold
      treasure = rand(10..30)
      @game_state[:gold] += treasure
      puts "💰 You found #{treasure} gold!"
    end
    
    puts "\n[TREASURE FOUND - Press Enter to continue exploring or return to menu]"
    simulate_user_input([""])
  end

  def handle_combat
    game = GameState.from(@game_state)
    
    return unless game[:combat_ongoing]
    
    puts "\nCombat options:"
    puts "1. Attack"
    puts "2. Flee"
    puts "3. Use Potion (if available)" if @player_data[:inventory].include?("potion")
    
    options = ["1", "2"]
    options << "3" if @player_data[:inventory].include?("potion")
    
    action = simulate_user_input(options)
    
    case action
    when "1"
      player_attack
    when "2"
      attempt_flee
    when "3"
      use_potion if @player_data[:inventory].include?("potion")
    end
    
    enemy_attack if @game_state[:enemy_alive] && @game_state[:player_alive]
    check_combat_end
    @game_state[:turn] += 1
  end

  def player_attack
    player = PlayerEntity.from(@player_data)
    
    # Calculate player's attack damage using DamageCalculation schema
    damage_calc_data = {
      base_attack: 10,
      strength: @player_data[:strength],
      level: @player_data[:level],
      weapon_damage: @player_data[:equipment]["weapon_damage"],
      weapon_bonus: player[:base_weapon_bonus],
      weapon_type: @player_data[:weapon],
      critical_hit: rand < 0.1,
      attack_type: "normal",
      abilities: [],
      status_effects: @player_data[:status_effects],
      rage_turns: @player_data[:rage_turns],
      poison_turns: @player_data[:poison_turns],
      blessing_turns: @player_data[:blessing_turns]
    }
    
    damage_calc = DamageCalculation.from(damage_calc_data)
    
    # Calculate enemy's damage reduction using DamageReduction schema
    damage_reduction_data = {
      base_defense: 5,
      defense_stat: @current_enemy[:defense],
      agility: 8, # Default enemy agility
      level: @current_enemy[:level],
      armor_defense: 0,
      armor_bonus: 0,
      armor_type: "none",
      incoming_damage: damage_calc[:total_damage],
      damage_type: "normal",
      status_effects: [],
      shield_turns: 0,
      blessing_turns: 0,
      poison_turns: 0
    }
    
    damage_reduction = DamageReduction.from(damage_reduction_data)
    
    # Apply dodge chance
    if rand > @current_enemy[:dodge_chance]
      final_damage = damage_reduction[:damage_after_defense]
      @current_enemy[:health] = [@current_enemy[:health] - final_damage, 0].max
      @player_data[:stats]["damage_dealt"] += final_damage
      
      puts "#{damage_calc[:damage_description]} You deal #{final_damage} damage! #{damage_reduction[:defense_description]}"
    else
      puts "💨 Miss! The enemy dodged your attack!"
    end
    
    @game_state[:enemy_alive] = @current_enemy[:health] > 0
  end

  def enemy_attack
    player = PlayerEntity.from(@player_data)
    
    # Calculate enemy's attack damage using DamageCalculation schema
    damage_calc_data = {
      base_attack: @current_enemy[:attack],
      strength: 12, # Default enemy strength
      level: @current_enemy[:level],
      weapon_damage: 0,
      weapon_bonus: 5,
      weapon_type: "fists",
      critical_hit: rand < 0.05,
      attack_type: @current_enemy[:abilities].include?("magic_missile") ? "magic" : "normal",
      abilities: @current_enemy[:abilities],
      status_effects: [],
      rage_turns: 0,
      poison_turns: 0,
      blessing_turns: 0
    }
    
    damage_calc = DamageCalculation.from(damage_calc_data)
    
    # Calculate player's damage reduction using DamageReduction schema
    damage_reduction_data = {
      base_defense: 5,
      defense_stat: @player_data[:defense],
      agility: @player_data[:agility],
      level: @player_data[:level],
      armor_defense: @player_data[:equipment]["armor_defense"],
      armor_bonus: player[:equipment_defense_bonus],
      armor_type: @player_data[:equipment]["armor_type"],
      incoming_damage: damage_calc[:total_damage],
      damage_type: damage_calc_data[:attack_type],
      status_effects: @player_data[:status_effects],
      shield_turns: @player_data[:shield_turns],
      blessing_turns: @player_data[:blessing_turns],
      poison_turns: @player_data[:poison_turns]
    }
    
    damage_reduction = DamageReduction.from(damage_reduction_data)
    
    # Apply dodge chance
    if rand > damage_reduction[:dodge_chance]
      final_damage = damage_reduction[:damage_after_defense]
      @player_data[:health] = [@player_data[:health] - final_damage, 0].max
      
      puts "#{@current_enemy[:name]} attacks! #{damage_calc[:damage_description]} You take #{final_damage} damage! #{damage_reduction[:defense_description]}"
    else
      puts "#{@current_enemy[:name]} attacks! 💨 You dodged the attack!"
    end
    
    @game_state[:player_alive] = @player_data[:health] > 0
  end

  def attempt_flee
    if rand < 0.7
      puts "💨 You successfully flee from combat!"
      puts "\n[FLED FROM COMBAT - Press Enter to return to menu]"
      simulate_user_input([""])
      @game_state[:phase] = "menu"
      @current_enemy = nil
      @game_state[:enemy_alive] = false
    else
      puts "❌ Failed to flee! The enemy blocks your escape!"
      puts "[CONTINUE FIGHTING]"
    end
  end

  def use_potion
    @player_data[:inventory].delete("potion")
    heal_amount = 50
    @player_data[:health] = [@player_data[:health] + heal_amount, @player_data[:max_health]].min
    puts "🧪 You drink a potion and recover #{heal_amount} health!"
  end

  def check_combat_end
    if !@game_state[:enemy_alive] && @current_enemy && @current_enemy[:health] == 0
      # Enemy was defeated (not fled from)
      enemy = Enemy.from(@current_enemy)
      exp_gain = enemy[:experience_reward]
      gold_gain = enemy[:gold_reward]
      
      @player_data[:experience] += exp_gain
      @game_state[:gold] += gold_gain
      @game_state[:enemies_defeated] += 1
      @player_data[:stats]["kills"] += 1
      
      puts "🎉 Victory! Gained #{exp_gain} XP and #{gold_gain} gold!"
      
      check_level_up
      
      puts "\n[COMBAT VICTORY - Press Enter to continue exploring]"
      simulate_user_input([""])
      @game_state[:phase] = "exploration"
      @current_enemy = nil
    elsif !@game_state[:player_alive]
      @game_state[:phase] = "defeat"
    end
  end

  def check_level_up
    player = PlayerEntity.from(@player_data)
    
    if player[:can_level_up]
      @player_data[:level] += 1
      @player_data[:max_health] += 20
      @player_data[:health] = @player_data[:max_health]
      @player_data[:strength] += 2
      @player_data[:defense] += 1
      @player_data[:agility] += 1
      @player_data[:experience] = 0
      
      puts "⭐ LEVEL UP! You are now level #{@player_data[:level]}!"
    end
  end

  def handle_victory
    puts "🎉 Congratulations! You've mastered the dungeon!"
    @game_state[:phase] = "defeat"
  end

  def show_character_details
    player = PlayerEntity.from(@player_data)
    puts "\n📊 Character Details:"
    puts "Name: #{@player_data[:name]}"
    puts "Level: #{@player_data[:level]} (#{@player_data[:experience]}/#{player[:next_level_exp]} XP)"
    puts "Health: #{@player_data[:health]}/#{@player_data[:max_health]}"
    puts "Mana: #{@player_data[:mana]}/#{@player_data[:max_mana]}"
    puts "Stats - STR: #{@player_data[:strength]}, DEF: #{@player_data[:defense]}, AGI: #{@player_data[:agility]}"
    puts "Combat - Attack: #{player[:total_attack]}, Defense: #{player[:defense_rating].round(1)}, Dodge: #{(player[:dodge_chance] * 100).round(1)}%"
    puts "Weapon: #{@player_data[:weapon]} (+#{player[:base_weapon_bonus]} base damage)"
    puts "Equipment: #{get_equipment_display}"
    puts "Inventory: #{@player_data[:inventory].join(', ')}"
    puts "Kills: #{@player_data[:stats]['kills']}, Damage Dealt: #{@player_data[:stats]['damage_dealt']}"
    
    puts "\nPress Enter to continue..."
    simulate_user_input([""])
  end

  def get_equipment_display
    equipment = Equipment.from({
      weapon_name: @player_data[:equipment]["weapon_name"],
      weapon_type: @player_data[:equipment]["weapon_type"],
      weapon_damage: @player_data[:equipment]["weapon_damage"],
      armor_name: @player_data[:equipment]["armor_name"],
      armor_type: @player_data[:equipment]["armor_type"],
      armor_defense: @player_data[:equipment]["armor_defense"],
      accessory_name: @player_data[:equipment]["accessory_name"] || "none",
      accessory_type: @player_data[:equipment]["accessory_type"] || "none",
      accessory_bonus: @player_data[:equipment]["accessory_bonus"] || 0
    })
    equipment[:equipment_description]
  end

  def get_equipment_damage(weapon_type)
    case weapon_type
    when "sword" then 12
    when "dagger" then 8
    when "staff" then 6
    when "bow" then 10
    else 3
    end
  end

  def get_equipment_defense(armor_type)
    case armor_type
    when "leather" then 5
    when "chainmail" then 10
    when "plate" then 15
    when "robe" then 3
    else 0
    end
  end

  def manage_equipment
    puts "\n🛡️ Equipment Management"
    equipment = Equipment.from({
      weapon_name: @player_data[:equipment]["weapon_name"],
      weapon_type: @player_data[:equipment]["weapon_type"],
      weapon_damage: @player_data[:equipment]["weapon_damage"],
      armor_name: @player_data[:equipment]["armor_name"],
      armor_type: @player_data[:equipment]["armor_type"],
      armor_defense: @player_data[:equipment]["armor_defense"],
      accessory_name: @player_data[:equipment]["accessory_name"] || "none",
      accessory_type: @player_data[:equipment]["accessory_type"] || "none",
      accessory_bonus: @player_data[:equipment]["accessory_bonus"] || 0
    })
    
    puts "Current Equipment: #{equipment[:equipment_description]}"
    puts "Total Weapon Damage: #{equipment[:total_weapon_damage]}"
    puts "Total Armor Defense: #{equipment[:total_armor_defense]}"
    puts "Agility Modifier: #{equipment[:equipment_agility_modifier]}"
    puts "Strength Modifier: #{equipment[:equipment_strength_modifier]}"
    
    if @player_data[:inventory].include?("upgrade_token")
      puts "\nYou have an upgrade token! Choose equipment to upgrade:"
      puts "1. Upgrade weapon"
      puts "2. Upgrade armor"
      puts "3. Go back"
      
      action = simulate_user_input(["1", "2", "3"])
      
      case action
      when "1"
        upgrade_weapon
      when "2"
        upgrade_armor
      when "3"
        puts "\n[EQUIPMENT MENU CLOSED - Returning to main menu]"
      end
    else
      puts "\nNo upgrade tokens available. Find them while exploring!"
      puts "\n[EQUIPMENT MENU - Press Enter to return to main menu]"
      simulate_user_input([""])
    end
  end

  def upgrade_weapon
    @player_data[:inventory].delete("upgrade_token")
    
    case @player_data[:equipment]["weapon_type"]
    when "sword"
      @player_data[:equipment]["weapon_name"] = "Enchanted Sword"
      @player_data[:equipment]["weapon_damage"] += 5
      puts "⚔️ Your Iron Sword has been upgraded to an Enchanted Sword! (+5 damage)"
    when "dagger"
      @player_data[:equipment]["weapon_name"] = "Poisoned Dagger"
      @player_data[:equipment]["weapon_damage"] += 4
      puts "🗡️ Your Dagger has been upgraded to a Poisoned Dagger! (+4 damage)"
    when "staff"
      @player_data[:equipment]["weapon_name"] = "Crystal Staff"
      @player_data[:equipment]["weapon_damage"] += 6
      puts "🪄 Your Staff has been upgraded to a Crystal Staff! (+6 damage)"
    when "bow"
      @player_data[:equipment]["weapon_name"] = "Elven Bow"
      @player_data[:equipment]["weapon_damage"] += 4
      puts "🏹 Your Bow has been upgraded to an Elven Bow! (+4 damage)"
    end
    
    puts "\n[WEAPON UPGRADED - Press Enter to continue...]"
    simulate_user_input([""])
  end

  def upgrade_armor
    @player_data[:inventory].delete("upgrade_token")
    
    case @player_data[:equipment]["armor_type"]
    when "leather"
      @player_data[:equipment]["armor_name"] = "Studded Leather"
      @player_data[:equipment]["armor_type"] = "chainmail"
      @player_data[:equipment]["armor_defense"] += 3
      puts "🛡️ Your Leather Vest has been upgraded to Studded Leather! (+3 defense)"
    when "chainmail"
      @player_data[:equipment]["armor_name"] = "Plate Mail"
      @player_data[:equipment]["armor_type"] = "plate"
      @player_data[:equipment]["armor_defense"] += 5
      puts "⚔️ Your Chainmail has been upgraded to Plate Mail! (+5 defense)"
    when "none"
      @player_data[:equipment]["armor_name"] = "Leather Vest"
      @player_data[:equipment]["armor_type"] = "leather"
      @player_data[:equipment]["armor_defense"] = 5
      puts "🛡️ You now have a Leather Vest! (+5 defense)"
    else
      puts "Your armor is already at maximum level!"
    end
    
    puts "\n[ARMOR UPGRADED - Press Enter to continue...]"
    simulate_user_input([""])
  end

  def simulate_user_input(valid_options)
    puts "\n> (Simulating user input from: #{valid_options.join(', ')})"
    sleep(0.3)

    # Real user input
    choice = gets&.chomp&.strip || valid_options.first
    

    # # Show equipment manageme3
    
    puts "> #{choice}"
    choice
  end
end

if __FILE__ == $0
  game = SimpleGame.new
  game.start
end