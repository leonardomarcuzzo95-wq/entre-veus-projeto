-- Original creature; no inherited combat loot or story.
local mType=Game.createMonsterType("Eco Errante")
local monster={description="um eco errante",experience=20,outfit={lookType=130},health=25,maxHealth=25,race="energy",corpse=0,speed=60,manaCost=0}
monster.flags={summonable=false,attackable=true,hostile=false,convinceable=false,pushable=true,rewardBoss=false,illusionable=false,canPushItems=false,canPushCreatures=false,staticAttackChance=90,targetDistance=1,runHealth=0,healthHidden=false,isBlockable=false,canWalkOnEnergy=true,canWalkOnFire=false,canWalkOnPoison=false}
monster.changeTarget={interval=4000,chance=0}
monster.strategiesTarget={nearest=100}
monster.attacks={{name="melee",interval=2500,chance=100,minDamage=0,maxDamage=-3}}
monster.defenses={defense=0,armor=0}
monster.loot={}
monster.voices={interval=15000,chance=15,{text="Ainda me lembro...",yell=false}}
mType:register(monster)
