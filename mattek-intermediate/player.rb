require 'logger'

class Player
	@@wasAttacking = false
	@@previousHealth = 20
	@@direction = :forward
	@@directions = [:forward,:right,:backward,:left]
	@@spaces = [
		nil,nil,nil,nil,nil,nil,nil,
		nil,nil,nil,nil,nil,nil,nil,
		nil,nil,nil,nil,nil,nil,nil,
		nil,nil,nil,"x",nil,nil,nil,
		nil,nil,nil,nil,nil,nil,nil,
		nil,nil,nil,nil,nil,nil,nil,
		nil,nil,nil,nil,nil,nil,nil
	]
	@@size = [7,7]
	@@position = [3,3]
	@@wasDetonating = false
	@@log = Logger.new(STDOUT)

	def play_turn(warrior)
		if warrior.respond_to? :health
			if warrior.health < @@previousHealth
				isLosingHealth = true
			else
				isLosingHealth = false
			end
		end

		logSpaces()

		anyArcher = false
		anyWizard = false
		anySludge = false
		anyCaptive = false
		anyCaptiveNear = false
		anyCaptiveTicking = false
		anyToBind = false
		anyEscape = false

		bindDirection = nil
		captiveDirection = nil
		escapeDirections = []
		tickingDirection = nil
		tickingDistance = 1000

		nearEnemyCount = 0

		isNear = false

		canDetonate = true

		directions = @@directions

		previousDirection = @@direction
		nextDirection = @@direction

		if warrior.respond_to? :listen
			warrior.listen.each do |space|
				if space.to_s == "Captive" && space.ticking?
					@@log.info("space(#{warrior.direction_of(space)}):#{space} (#{warrior.distance_of(space)})")

					tickingDistance = warrior.distance_of(space)
					tickingDirection = warrior.direction_of(space)

					anyCaptiveTicking = true

					if previousDirection != tickingDirection && warrior.distance_of(space) == 2 &&
							(hasSpace(@@directions[0],"x",1) || hasSpace(@@directions[1],"x",1) || 
							hasSpace(@@directions[2],"x",1) || hasSpace(@@directions[3],"x",1))
						@@log.info("Continue with old ticking direction to #{previousDirection}")
						tickingDirection = previousDirection
					end

					directions.delete(tickingDirection)
					@@log.info("directions:#{directions}")
					directions.insert(0, tickingDirection)
					@@log.info("directions:#{directions}")

					if warrior.distance_of(space) == 1
						break
					end
				end
			end
		end

		directions.each do |direction|
			if warrior.respond_to? :look
				spaces = warrior.look(direction)
			else
				spaces = [ warrior.feel(direction) ]
			end

			distance = 1

			spaces.each do |space|
				@@log.info("space(#{direction}):#{space} (#{distance})")
				
				nothing = true
				isEnemy = false

				if !isNear || (isNear && distance == 1)
					if space.to_s == "Captive" && distance == 1
						anyCaptiveNear = true
						captiveDirection = direction
						nothing = false
						setSpace(direction, "C", distance)
					elsif space.to_s == "Wizard"
						anyWizard = true
						nothing = false
						isEnemy = true
						if !hasSpace(direction, "B", distance)
							setSpace(direction, "E", distance)
						end
					elsif space.to_s == "Archer"
						anyArcher = true
						nothing = false
						isEnemey = true
						if !hasSpace(direction, "B", distance)
							setSpace(direction, "E", distance)
						end
					elsif space.to_s == "Sludge" || space.to_s == "Thick Sludge"
						anySludge = true
						nothing = false
						isEnemy = true
						if !hasSpace(direction, "B", distance)
							setSpace(direction, "E", distance)
						end
					elsif space.to_s == "Captive"
						anyCaptive = true
						nothing = false
						if !hasSpace(direction, "B", distance)
							setSpace(direction, "C", distance)
						end
					elsif space.to_s == "nothing" && distance == 1
						anyEscape = true
						escapeDirections.push(direction)
						if !hasSpace(direction, "x", distance)
							setSpace(direction, nil, distance)
						end
					end

					if (distance > 1 && (anyArcher || anyWizard)) || (distance == 2 && isEnemy)
						anyEscape = false
					end
				end

				if !nothing
					if distance == 1
						isNear = true
						if isEnemy
							nearEnemyCount = nearEnemyCount + 1
						end

						if isEnemy && nearEnemyCount > 1 && !anyToBind && !hasSpace(direction,"B",1)
							anyToBind = true
							bindDirection = direction
						end
					else
						isNear = false
					end

					nextDirection = direction

					break
				end
			
				distance = distance + 1
			end
		end

		anyRemember = false
		rememberDirection = nil

		if !anyArcher && !anyWizard && !anySludge && !anyCaptive && !anyCaptiveTicking
			@@log.info("wait, let's remember a bit")

			index = 0

			rememberDistance = 0
			rememberPosition = nil
			
			@@spaces.each do |space|
				position = [ index%@@size[0],index/@@size[0] ]
				
				if !(@@spaces[position[0] + position[1] * @@size[0]] == nil) && !(@@spaces[position[0] + position[1] * @@size[0]] == "x")
					distance = (position[0] - @@position[0]).abs**2 + (position[1] - @@position[1]).abs**2

					@@log.info("on #{position[0]},#{position[1]} there was #{@@spaces[position[0] + position[1] * @@size[0]]} (#{distance})")

					if distance > rememberDistance
						rememberDistance = distance
						rememberPosition = position
						anyRemember = true
					end
				end
				
				index = index + 1
			end

			if anyRemember
				difference = [ @@position[0] - rememberPosition[0], @@position[1] - rememberPosition[1] ]
				
				if difference[0].abs < difference [1].abs
					if difference[1] < 0
						rememberDirection = :right
					else
						rememberDirection = :left
					end
				else
					if difference[0] < 0
						rememberDirection = :forward
					else
						rememberDirection = :backward
					end
				end

				@@log.info("i think i saw something on #{rememberDirection}")
			end
		end

		if !anyArcher && !anyWizard && !anySludge && !anyCaptive && !anyCaptiveTicking
			if anyRemember
				nextDirection = rememberDirection
			else
				nextDirection = warrior.direction_of_stairs
			end
		end

		@@log.info("anyEnemy(#{nextDirection}):#{anyArcher || anyWizard || anySludge} (near: #{isNear})")

		if canDetonate && (warrior.respond_to? :look)
			canDetonate = false

			if anyCaptiveTicking
				bombDirection = tickingDirection
			else
				bombDirection = nextDirection
			end

			@@log.info("looking for detonation (#{bombDirection}) #{warrior.look(bombDirection)}")
			distance = 1
			allEnemies = true
			warrior.look(bombDirection).each do |space|
				if distance <= 2 && (space.to_s == "Wizard" || space.to_s == "Archer" ||
						space.to_s == "Sludge" || space.to_s == "Thick Sludge")
					canDetonate = true
				elsif distance <= 2 && !(space.to_s == "Wizard" || space.to_s == "Archer" ||
						space.to_s == "Sludge" || space.to_s == "Thick Sludge")
					allEnemies = false
				elsif distance <= 3 && space.to_s == "Captive"
					canDetonate = false
					break
				end
				distance = distance + 1
			end

			if canDetonate && !allEnemies && warrior.health == 20 && anyCaptiveTicking
				canDetonate = false
			end
		else
			canDetonate = false
		end

		wayToCaptiveBlocked = false

		if anyCaptiveTicking
			@@log.info("i've heard a ticking captive and going to rescue to #{tickingDirection}!")

			if (!anyCaptiveNear && !(escapeDirections.include? tickingDirection)) || (canDetonate && tickingDistance >= 3)
				@@log.info("Seems that way to rescue the captive is blocked!")

				blockedTickingDirection = tickingDirection				

				if anyEscape
					escapeDirections.each do |escapeDirection|
						if !opposite(escapeDirection,tickingDirection) && !opposite(escapeDirection,previousDirection) && !hasSpace(escapeDirection,"x",1)
							tickingDirection = escapeDirection
						end
					end
				end

				if blockedTickingDirection == tickingDirection
					@@log.info("found obstacle on  #{tickingDirection} but no escape!")
					wayToCaptiveBlocked = true
					nextDirection = tickingDirection
				else
					@@log.info("found obstacle, escaping to #{tickingDirection}!")
				end
			end
		end

		hasDetonated = false

		if anyCaptiveTicking && !wayToCaptiveBlocked
			if anyCaptiveNear
				@@log.info("there's a captive on #{captiveDirection}, let's save him!")

				warrior.rescue!(captiveDirection)
			elsif warrior.health <= 3
				@@log.info("i rest a bit")
		
				warrior.rest!
			else
				@@log.info("Move to rescue ticking captive on #{tickingDirection}, let's save him!")

				nextDirection = tickingDirection

				warrior.walk!(nextDirection)

				updateSpaces(nextDirection)

				@@direction = nextDirection
			end
		elsif isLosingHealth && warrior.health <= 8 && anyEscape && !anyCaptiveTicking && (anyArcher || anyWizard || anySludge && isNear)
			@@log.info("i am dying i'll try a retreat to #{escapeDirections[0]}!")
			nextDirection = escapeDirections[0]

			warrior.walk!(nextDirection)

			updateSpaces(nextDirection)

			@@direction = nextDirection
		elsif anyToBind
			@@log.info("lets bind you bastard")

			warrior.bind!(bindDirection)

			setSpace(bindDirection, "B", 1)
		elsif anyCaptiveNear
			@@log.info("there's a captive on #{captiveDirection}, let's save him!")

			warrior.rescue!(captiveDirection)

			@@wasAttacking = false
		elsif (anyArcher || anyWizard || anySludge) && (isNear || (warrior.respond_to? :shoot) || canDetonate)
			@@log.info("argh, an enemy on #{nextDirection}, attacking him!")

			if canDetonate
				if warrior.health <= 4
					@@log.info("must rest a bit before detonate")
		
					warrior.rest!
				else
					warrior.detonate!(nextDirection)
				end
			elsif warrior.respond_to? :shoot
				warrior.shoot!(nextDirection)
			else
				warrior.attack!(nextDirection)
			end

			@@wasAttacking = true
		elsif anyCaptive
			@@log.info("there's a captive on #{captiveDirection}, let's save him!")

			if warrior.feel(nextDirection).captive?
				warrior.rescue!(nextDirection)
			else
				warrior.walk!(nextDirection)

				updateSpaces(nextDirection)

				@@direction = nextDirection
			end

			@@wasAttacking = false
		else
			canCountinue = true

			if warrior.respond_to? :health
				canContinue = false

				if warrior.health < 10
					@@log.info("i should rest until cured!")

					warrior.rest!
				else
					canContinue = true
				end
			end

			if canContinue
				@@log.info("continue my way!")

				if (warrior.feel(nextDirection).wall? || hasSpace(nextDirection, "x",1)) ||
						((anyRemember || anyArcher || anyWizard || anySludge || anyCaptive) && warrior.feel(nextDirection).stairs?)
					@@log.info("looking escapes: #{escapeDirections}")

					if escapeDirections.include? previousDirection
						escapeDirections.delete(previousDirection)
						escapeDirections.push(previousDirection)
					end

					escapeDirections.each do |direction|
						if !warrior.feel(direction).wall? && ((!anyRemember && !anyArcher && !anyWizard && !anySludge && !anyCaptive) || !warrior.feel(direction).stairs?)
							nextDirection = direction
							
							if !hasSpace(direction, "x",1)
								break
							end
						end
					end

					@@log.info("hmm, this path is not new let's go to #{nextDirection} instead!")
				end

				warrior.walk!(nextDirection)

				updateSpaces(nextDirection)

				@@direction = nextDirection
			end
			@@wasAttacking = false
		end
		
		if warrior.respond_to? :health
			@@previousHealth = warrior.health
		end

		if hasDetonated
			@@wasDetonating = true
		else
			@@wasDetonating = false
		end
	end

	def updateSpaces(direction)
		@@spaces[@@position[0] + @@position[1] * @@size[0]] = "x"

		if direction == :forward
			if @@position[0] + 5 > @@size[0]
				1.upto(@@size[1]).each do |x|
					@@spaces.insert((@@size[1] - x + 1) * @@size[0], nil)
				end

				@@size[0] = @@size[0] + 1
			end

			@@position[0] = @@position[0] + 1
		elsif direction == :right
			if @@position[1] + 5 > @@size[1]
				1.upto(@@size[0]).each do |x|
					@@spaces.push(nil)
				end

				@@size[1] = @@size[1] + 1
			end

			@@position[1] = @@position[1] + 1
		elsif direction == :backward
			if @@position[0] > 1
				@@position[0] = @@position[0] - 1
			else 
				1.upto(@@size[1]).each do |x|
					@@spaces.insert((@@size[1] - x) * @@size[0], nil)
				end

				@@size[0] = @@size[0] + 1
			end
		elsif direction == :left
			if @@position[1] > 1
				@@position[1] = @@position[1] - 1
			else 
				1.upto(@@size[0]).each do |x|
					@@spaces.insert(0, nil)
				end

				@@size[1] = @@size[1] + 1
			end
		end
	end

	def setSpace(direction, value, distance)
		if direction == :forward
			@@spaces[@@position[0] + distance + @@position[1] * @@size[0]] = value
		elsif direction == :right
			@@spaces[@@position[0] + (@@position[1] + distance) * @@size[0]] = value
		elsif direction == :backward
			@@spaces[@@position[0] - distance + @@position[1] * @@size[0]] = value
		elsif direction == :left
			@@spaces[@@position[0] + (@@position[1] - distance) * @@size[0]] = value
		end
	end

	def hasSpace(direction,value,distance)
		if direction == :forward
			return @@spaces[@@position[0] + distance + @@position[1] * @@size[0]] == value
		elsif direction == :right
			return @@spaces[@@position[0] + (@@position[1] + distance) * @@size[0]] == value
		elsif direction == :backward
			return @@spaces[@@position[0] - distance + @@position[1] * @@size[0]] == value
		elsif direction == :left
			return @@spaces[@@position[0] + (@@position[1] - distance) * @@size[0]] == value
		end
		
		return false
	end

	def logSpaces()
		spaceMap = "\n"
		spaceMap = spaceMap + "+"
		1.upto(@@size[0]).each do |x|
			spaceMap = spaceMap + "-"
		end
		spaceMap = spaceMap + "+\n"

		1.upto(@@size[1]).each do |y|
			spaceMap = spaceMap + "|"
			1.upto(@@size[0]).each do |x|
				space = " "
				if x - 1 == @@position[0] && y - 1 == @@position[1]
					space = "@"
				elsif @@spaces[x - 1 + (y  - 1) * @@size[0]] != nil
					space = @@spaces[x - 1 + (y  - 1) * @@size[0]]
				end
				spaceMap = spaceMap + space
			end
			spaceMap = spaceMap + "|"
			spaceMap = spaceMap + "\n"
		end

		spaceMap = spaceMap + "+"
		1.upto(@@size[0]).each do |x|
			spaceMap = spaceMap + "-"
		end
		spaceMap = spaceMap + "+"

		@@log.info(spaceMap)
	end

	def opposite(direction1, direction2)
		if (direction1 == :forward && direction2 == :backward) ||
		(direction1 == :backward && direction2 == :forward) ||
		(direction1 == :right && direction2 == :left) ||
		(direction1 == :left && direction2 == :right)
			return true
		end

		return false
	end

end
