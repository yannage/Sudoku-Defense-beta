/**
 * attacks.js - Handles tower attack logic
 * This module manages tower targeting, attack timing, and damage calculation.
 */

const TowerAttacks = (function() {
    /**
     * Update all towers, processing attacks
     * @param {number} deltaTime - Time elapsed since last update in seconds
     */
    function update(deltaTime) {
        if (!window.TowerPlacement || !window.EnemiesModule) {
            return;
        }
        
        const enemies = EnemiesModule.getEnemies();
        
        if (enemies.length === 0) {
            return;
        }
        
        // Get all towers
        const towers = TowerPlacement.getTowers();
        
        // Update each tower
        for (let i = 0; i < towers.length; i++) {
            const tower = towers[i];
            
            // Update attack cooldown
            if (tower.attackCooldown > 0) {
                tower.attackCooldown -= deltaTime;
            }
            
            // Skip if tower is on cooldown
            if (tower.attackCooldown > 0) {
                continue;
            }
            
            // Find a target for the tower
            const target = findTarget(tower, enemies);
            
            if (target) {
                // Attack the target
                attackEnemy(tower, target);
                
                // Set attack cooldown
                tower.attackCooldown = tower.attackSpeed;
            }
        }
    }
    
    /**
     * Find a target for a tower
     * @param {Object} tower - The tower
     * @param {Object[]} enemies - Array of enemies
     * @returns {Object|null} The target enemy or null if no target found
     */
    function findTarget(tower, enemies) {
        // Special tower attacks any enemy in range
        if (tower.type === 'special') {
            return findClosestEnemy(tower, enemies);
        }
        
        // Parse tower number
        const towerNumber = parseInt(tower.type);
        if (isNaN(towerNumber)) {
            return null;
        }
        
        // Calculate the range of enemy numbers this tower can attack
        // A tower can attack its own number and up to 2 higher numbers
        const minTargetNumber = towerNumber;
        const maxTargetNumber = towerNumber + 2;
        
        // Filter enemies by eligible type numbers
        const matchingEnemies = enemies.filter(enemy => {
            // Convert enemy type to a number
            let enemyType = enemy.type;
            
            // If it's a string (like emoji "1️⃣"), convert to number
            if (typeof enemyType === 'string') {
                // Try to extract the first digit
                const match = enemyType.match(/\d+/);
                if (match) {
                    enemyType = parseInt(match[0]);
                } else if (enemyType === 'boss') {
                    // Special case for boss - all towers can attack the boss
                    return true;
                } else {
                    // If we can't parse a number, try direct parseInt
                    enemyType = parseInt(enemyType);
                }
            }
            
            // Check if the enemy number is within the tower's target range
            return !isNaN(enemyType) && 
                   enemyType >= minTargetNumber && 
                   enemyType <= maxTargetNumber;
        });
        
        // Find the closest eligible enemy
        return findClosestEnemy(tower, matchingEnemies);
    }
    
    /**
     * Find the closest enemy within range
     * @param {Object} tower - The tower
     * @param {Object[]} enemies - Array of enemies
     * @returns {Object|null} The closest enemy or null if no enemy in range
     */
    function findClosestEnemy(tower, enemies) {
        let closestEnemy = null;
        let closestDistance = Infinity;
        
        for (let i = 0; i < enemies.length; i++) {
            const enemy = enemies[i];
            
            // Calculate distance
            const dx = enemy.x - tower.x;
            const dy = enemy.y - tower.y;
            const distance = Math.sqrt(dx * dx + dy * dy);
            
            // Check if enemy is in range and closer than current closest
            if (distance <= tower.range && distance < closestDistance) {
                closestEnemy = enemy;
                closestDistance = distance;
            }
        }
        
        return closestEnemy;
    }
    
    /**
     * Attack an enemy
     * @param {Object} tower - The tower
     * @param {Object} enemy - The enemy
     */
    function attackEnemy(tower, enemy) {
        if (!window.EnemiesModule) {
            return;
        }
        
        // Get base values
        const baseDamage = tower.damage;
        const basePoints = enemy.points || 5;
        const baseCurrency = enemy.reward || 10;
        
        // Apply completion bonuses if the module exists
        let damage = baseDamage;
        let points = basePoints;
        let currency = baseCurrency;
        
        if (window.CompletionBonusModule && 
            typeof CompletionBonusModule.applyEffects === 'function') {
            const bonusEffects = CompletionBonusModule.applyEffects(
                tower, enemy, basePoints, baseCurrency
            );
            damage = bonusEffects.damage;
            points = bonusEffects.points;
            currency = bonusEffects.currency;
        }
        
        // Damage the enemy
        const isKilled = EnemiesModule.damageEnemy(enemy.id, damage);
        
        // Publish tower attack event with bonus information
        EventSystem.publish(GameEvents.TOWER_ATTACK, {
            tower: tower,
            enemy: enemy,
            damage: damage,
            killed: isKilled,
            points: isKilled ? points : 0,
            currency: isKilled ? currency : 0
        });
    }
    
    /**
     * Initialize event listeners
     */
    function initEventListeners() {
        // Subscribe to game update event to process attacks
        EventSystem.subscribe(GameEvents.GAME_UPDATE, update);
    }
    
    // Initialize event listeners
    initEventListeners();
    
    // Public API
    return {
        update,
        findTarget,
        findClosestEnemy,
        attackEnemy
    };
})();

// Make module available globally
window.TowerAttacks = TowerAttacks;