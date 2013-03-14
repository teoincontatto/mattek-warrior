require 'logger'

class Player
	@@wasAttacking = false
	@@previousHealth = 20

	def play_turn(warrior)
		log = Logger.new(STDOUT)

		if warrior.health < @@previousHealth
			isLosingHealth = true
		else
			isLosingHealth = false
		end

		anyArcher = false
		isArcherOnBack = false
		anyWizard = false
		isWizardOnBack = false
		anySludge = false
		isSludgeOnBack = false
		anyCaptive = false
		isCaptiveOnBack = false
		warrior.look(:backward).each do |x|
			log.info("x(:backward):#{x}")
			if x.to_s == "Wizard"
				anyWizard = true
				isWizardOnBack = true
				break
			elsif x.to_s == "Archer"
				anyArcher = true
				isArcherOnBack = true
				break
			elsif x.to_s == "Sludge" || x.to_s == "Thick Sludge"
				anySludge = true
				isSludgeOnBack = true
				break
			elsif x.to_s == "Captive"
				anyCaptive = true
				isCaptiveOnBack = true
				break
			elsif x.to_s != 'nothing'
				break
			end
		end
		warrior.look.each do |x|
			log.info("x:#{x}")
			if x.to_s == "Wizard"
				anyWizard = true
				isWizardOnBack = false
				break
			elsif x.to_s == "Archer"
				anyArcher = true
				isArcherOnBack = false
				break
			elsif x.to_s == "Sludge" || x.to_s == "Thick Sludge"
				anySludge = true
				isSludgeOnBack = false
				break
			elsif x.to_s == "Captive"
				anyCaptive = true
				isCaptiveOnBack = false
				break
			elsif x.to_s != 'nothing'
				break
			end
		end

		if anyArcher || anyWizard || anySludge
			shootBack = anyWizard && isWizardOnBack
			shootBack ||= !anyWizard && anyArcher && isArcherOnBack
			shootBack ||= !anyWizard && !anyArcher && anySludge && isSludgeOnBack
			if shootBack
				warrior.shoot!(:backward)
			else
				warrior.shoot!
			end
			@@wasAttacking = true
		elsif warrior.feel.wall?
			warrior.pivot!
			@@wasAttacking = false
		elsif anyCaptive
			if warrior.feel.captive?
				warrior.rescue!
			elsif warrior.feel(:backward).captive?
				warrior.rescue!(:backward)
			elsif isCaptiveOnBack
				warrior.walk!(:backward)
			else
				warrior.walk!
			end

			@@wasAttacking = false
		else
			if warrior.health < 20
				warrior.rest!
			else
				warrior.walk!
			end
			@@wasAttacking = false
		end
		
		@@previousHealth = warrior.health
	end

end
