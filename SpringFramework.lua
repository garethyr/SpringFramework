SpringFramework = {}

SpringFramework.SpringActions = {OUTSIDE_OF_CONFINES = 1, MOVE_INTO_ALIGNMENT = 2, APPLY_FORCES = 3};
SpringFramework.OutsideOfConfinesOptions = {DO_NOTHING = 1, BREAK_SPRING = 2, MOVE_TO_REST_POSITION = 3, CALLBACK = 4};

function SpringFramework.create(target1, target2, springConfig)
	local spring = springConfig;
	
	--------------------
	--CONFIG VARIABLES--
	--------------------
	--spring.length = {min = #, rest = # (optional), max = #} OR {#, # (optional), #} --The minimum, optional resting and maximum length of the spring. Rest defaults to the middle of the spring, min and max are required
	--spring.primaryTarget = false or 1 or 2 --The primary target for the spring, where false means neither. Used to determine the spring's midpoint for various calculations. Defaults to false
	--spring.stiffness = # --The stiffness of the spring, which linearly affects how much force is applied by it. Defaults to 1
	--spring.stiffnessMultiplier = {#, #} --How much to multiply the stiffness by when applying spring forces. Defaults to 1X for both targets
	--spring.offsets = {Vector, Vector} --The offsets for object targets, to determine where the spring should be put vs the object's position. Defaults to Vector(0, 0) for both offsets
	--spring.applyForcesAtOffset = true or false --Whether forces should be applied at the offset or directly at the target object's position. Defaults to true
	--spring.rotAngle = # --The RotAngle for the spring, for springs that don't inherit RotAngle. Defaults to 0
	--spring.inheritsRotAngle = false or 1 or 2 --The index of the object this should inherit RotAngle from or false to have a fixed RotAngle. Defaults to false
	--spring.rotAngleOffset = # --An angle in radians to offset the spring's rotAngle from the object it inherits from, if there is one. Defaults to 0
	--spring.lockToSpringRotation = true or false or 1 or 2 --Whether object positions should be locked to the spring's rotation. True means both, false means none, number means that one locks. Defaults to true
	--spring.lockRotationVariance = {negativeAngle, positiveAngle} --The amount of positive and negative variation locked objects can have from the spring's RotAngle. Defaults to {0, 0}
	--spring.confinesToCheck = {min = true or false, max = true or false, absolute = true or false} --Whether or not to check the given confines for outsideOfConfinesAction, absolute being the absolute distance from the rest position. Defaults to true for all
	--spring.outsideOfConfinesAction = {1/2 = OutsideOfConfinesOptions.# or {type = OutsideOfConfinesOptions.#, callback = some_function_if_type_is_callback(spring, isOutsideOfConfines)}} --What to do when the spring is outside of its minimum or maximum confines. Options are DO_NOTHING, BREAK_SPRING which sets the spring to nil and returns, MOVE_TO_REST_POSITION which resets the position of the object to its rest position, CALLBACK which calls the function passed in as callback; said function is expected to take the spring and showing whether the object is outside of min, max and absolute confines as arguments, and return true if it did something or false if it didn't. Defaults to BREAK_SPRING for both
	--spring.minimumValuesForActions = {SpringActions.OUTSIDE_OF_CONFINES = #, SpringActions.MOVE_INTO_ALIGNMENT = #, SpringActions.APPLY_FORCES = #} --The minimum values required to perform each action. For outside confines this means objects must be this far from the min or max extension positions of the spring. For moving into alignment this means objects must be this many pixels out of alignment with the spring. For applying forces this means objects need to be this far from their expected resting point. Defaults to calculated values based on the spring's values
	--spring.maxForceStrength = {#, #} --The maximum non-impulse force the spring can apply to each object. Defaults to a calculated value based on the spring's values
	--spring.showDebug = true or false --Whether or not to draw debug position and force lines. Defaults to false

	------------------
	--DEFAULT VALUES--
	------------------
	spring.length = SpringFramework.calculateSpringLengths(spring.length);
	
	spring.primaryTarget = spring.primaryTarget ~= false and (spring.primaryTarget or false) or false;
	
	spring.stiffness = spring.stiffness or 1;
	spring.stiffnessMultiplier = spring.stiffnessMultiplier or {spring.stiffnessMultiplier and spring.stiffnessMultiplier[1] or 1, spring.stiffnessMultiplier and spring.stiffnessMultiplier[2] or 1};
	
	if (type(spring.offsets) == "table") then
		spring.offsets = #spring.offsets == 2 and spring.offsets or {spring.offsets[1], Vector(0, 0)};
	elseif (type(spring.offsets) == "userdata") then
		spring.offsets = {spring.offsets, Vector(0, 0)};
	else
		spring.offsets = {Vector(0, 0), Vector(0, 0)};
	end
	spring.applyForcesAtOffset = spring.applyForcesAtOffset ~= false and (spring.applyForcesAtOffset or true) or false;
	
	spring.rotAngle = spring.rotAngle or 0;
	spring.inheritsRotAngle = spring.inheritsRotAngle ~= false and (spring.inheritsRotAngle or false) or false;
	spring.rotAngleOffset = spring.rotAngleOffset or 0;
	
	spring.lockToSpringRotation = spring.lockToSpringRotation ~= false and (spring.lockToSpringRotation or true) or false;
	spring.lockRotationVariance = spring.lockRotationVariance or {0, 0};
	--Handle wrong argument ordering
	if (spring.lockRotationVariance[2] < 0 and spring.lockRotationVariance[1] > 0) then
		local variance = spring.lockRotationVariance[1];
		spring.lockRotationVariance = {spring.lockRotationVariance[2], variance};
	end
	--Lock variance to be in correct ranges
	spring.lockRotationVariance = {math.min(spring.lockRotationVariance[1], 0), math.max(spring.lockRotationVariance[2], 0)};
	
	spring.outsideOfConfinesAction = type(spring.outsideOfConfinesAction == "table") and spring.outsideOfConfinesAction or {};
	for i = 1, 2 do
		spring.outsideOfConfinesAction[i] = spring.outsideOfConfinesAction[i] or {type = SpringFramework.OutsideOfConfinesOptions.BREAK_SPRING};
		spring.outsideOfConfinesAction[i] = type(spring.outsideOfConfinesAction[i]) == "number" and {type = spring.outsideOfConfinesAction[i]} or spring.outsideOfConfinesAction[i];
		
		if (spring.outsideOfConfinesAction[i].type == SpringFramework.OutsideOfConfinesOptions.CALLBACK and type(spring.outsideOfConfinesAction[i].callback) ~= "function") then
			print("In order to use a callback for your Outside Of Confines Option, you must provide a function that takes the spring as an argument and returns true if it performed actions or false otherwise, under the key callback in the spring.outsideOfConfinesAction[#] table");
			return nil;
		end
	end
	spring.confinesToCheck = type(spring.confinesToCheck) == "table" and spring.confinesToCheck or {};
	spring.confinesToCheck.min = spring.confinesToCheck.min ~= false and (spring.confinesToCheck.min or true) or false;
	spring.confinesToCheck.max = spring.confinesToCheck.max ~= false and (spring.confinesToCheck.max or true) or false;
	spring.confinesToCheck.absolute = spring.confinesToCheck.absolute ~= false and (spring.confinesToCheck.absolute or true) or false;
	
	spring.minimumValuesForActions = spring.minimumValuesForActions or {};
	spring.minimumValuesForActions[SpringFramework.SpringActions.OUTSIDE_OF_CONFINES] = spring.minimumValuesForActions[SpringFramework.SpringActions.OUTSIDE_OF_CONFINES] or spring.length.difference * 0.5;
	spring.minimumValuesForActions[SpringFramework.SpringActions.MOVE_INTO_ALIGNMENT] = spring.minimumValuesForActions[SpringFramework.SpringActions.MOVE_INTO_ALIGNMENT] or spring.length.difference * 0.1;
	spring.minimumValuesForActions[SpringFramework.SpringActions.APPLY_FORCES] = spring.minimumValuesForActions[SpringFramework.SpringActions.APPLY_FORCES] or spring.length.difference * 0.1;
	
	spring.maxForceStrength = spring.maxForceStrength or {spring.length.difference * 0.5 * spring.stiffness * spring.stiffnessMultiplier[1], spring.length.difference * 0.5 * spring.stiffness * spring.stiffnessMultiplier[2]};
	
	spring.showDebug = spring.showDebug ~= false and (spring.showDebug or false) or false;
	
	----------------------------------
	--CALCULATED AND ASSIGNED VALUES--
	----------------------------------
	spring.targets = {target1, target2};
	spring.targetIsVector = {target1.ClassName == "Vector", target2.ClassName == "Vector"};
	
	if (spring.targetIsVector[1] and spring.targetIsVector[2]) then
		print("You cannot connect two Vectors with springs");
		return nil;
	end
	
	spring.drawAngle = spring.rotAngle;
	
	spring.pos = {};
	spring.distances = {{}, {}};
	spring.unrotatedDistances = {{}, {}};
	spring.forceStrengths = {};
	spring.forceVectors = {};
	
	SpringFramework.updateCalculations(spring);
	
	return spring;
end

function SpringFramework.calculateSpringLengths(lengthTable)
	local length = {min = lengthTable[1] or lengthTable.min, rest = lengthTable.rest, max = lengthTable[#lengthTable] or lengthTable.max};
	local prevMax = length.max;
	length.max = math.max(length.min, length.max);
	length.min = math.min(length.min, prevMax);
	length.difference = length.max - length.min;
	length.mid = length.min + length.difference * 0.5;
	length.rest = length.rest or (#lengthTable == 3 and math.max(length.min, lengthTable[2]) or length.mid);
	return length;
end

function SpringFramework.update(spring, noObjectUpdates)
	if (spring == nil or next(spring) == nil) then
		print("Trying to update spring that doesn't exist or has been BROKEN");
		return nil;
	end
	
	SpringFramework.updateCalculations(spring);
	
	if (noObjectUpdates ~= true) then
		SpringFramework.updateObjects(spring);
	end
	
	if (spring.showDebug == true) then
		SpringFramework.drawDebugLines(spring);
	end
	
	return next(spring) ~= nil and spring or nil;
end

function SpringFramework.updateCalculations(spring)
	spring.drawAngle = (spring.inheritsRotAngle == false or spring.targetIsVector[spring.inheritsRotAngle]) and spring.drawAngle or spring.targets[spring.inheritsRotAngle].RotAngle;
	spring.rotAngle = spring.drawAngle + (spring.inheritsRotAngle ~= false and spring.rotAngleOffset or 0); --Rotangle 0 is Target1 on Left, Target2 on Right
	
	SpringFramework.calculateAndUpdateTargetPositions(spring);
	
	SpringFramework.calculateAndUpdateSpringPositionsAndDistances(spring);
	
	SpringFramework.calculateAndUpdateForceValues(spring);
end

function SpringFramework.calculateAndUpdateTargetPositions(spring)
	spring.targetPos = {
		(spring.targetIsVector[1] and spring.targets[1] or spring.targets[1].Pos) + Vector(spring.offsets[1].X, spring.offsets[1].Y):RadRotate(spring.drawAngle),
		(spring.targetIsVector[2] and spring.targets[2] or spring.targets[2].Pos) + Vector(spring.offsets[2].X, spring.offsets[2].Y):RadRotate(spring.drawAngle)
	};
	spring.rotatedOffsets = {
		Vector(spring.offsets[1].X, spring.offsets[1].Y):RadRotate(spring.rotAngle),
		Vector(spring.offsets[2].X, spring.offsets[2].Y):RadRotate(spring.rotAngle)
	};
end

function SpringFramework.calculateAndUpdateSpringPositionsAndDistances(spring)
	if (spring.targetIsVector[1]) then
		spring.pos.mid = spring.targetPos[1] + Vector(spring.length.mid, 0):RadRotate(spring.rotAngle);
	elseif (spring.targetIsVector[2]) then
		spring.pos.mid = spring.targetPos[2] - Vector(spring.length.mid, 0):RadRotate(spring.rotAngle);
	else
		local distance = SceneMan:ShortestDistance(spring.targetPos[1], spring.targetPos[2], SceneMan.SceneWrapsX);
		
		if (spring.primaryTarget == false) then
			spring.pos.mid = spring.targetPos[1] + distance * 0.5;
		else
			spring.pos.mid = spring.targetPos[spring.primaryTarget] + distance * (spring.primaryTarget == 1 and 0.5 or -0.5);
		end
	end
	
	spring.pos[1] = {
		min = spring.pos.mid - Vector(spring.length.min * 0.5, 0):RadRotate(spring.rotAngle),
		rest = spring.pos.mid - Vector(spring.length.rest * 0.5, 0):RadRotate(spring.rotAngle),
		max = spring.pos.mid - Vector(spring.length.max * 0.5, 0):RadRotate(spring.rotAngle)
	};
	spring.pos[2] = {
		min = spring.pos.mid + Vector(spring.length.min * 0.5, 0):RadRotate(spring.rotAngle),
		rest = spring.pos.mid + Vector(spring.length.rest * 0.5, 0):RadRotate(spring.rotAngle),
		max = spring.pos.mid + Vector(spring.length.max * 0.5, 0):RadRotate(spring.rotAngle)
	};
	
	for i = 1, 2 do
		for posKey, posValue in pairs(spring.pos[i]) do
			spring.distances[i][posKey] = SceneMan:ShortestDistance(posValue, spring.targetPos[i], SceneMan.SceneWrapsX);
			spring.unrotatedDistances[i][posKey] = Vector(spring.distances[i][posKey].X, spring.distances[i][posKey].Y):RadRotate(-spring.rotAngle);
		end
	end
end

function SpringFramework.calculateAndUpdateForceValues(spring)
	for i = 1, 2 do
		if (not spring.targetIsVector[i]) then
			spring.forceStrengths[i] = math.min(spring.distances[i].rest.Magnitude * spring.stiffness * spring.stiffnessMultiplier[i], spring.maxForceStrength[i]);
			spring.forceVectors[i] = spring.distances[i].rest.Normalized * -spring.forceStrengths[i];
		end
	end
end

function SpringFramework.updateObjects(spring)
	spring.actionsPerformed = {};
	
	spring.actionsPerformed[SpringFramework.SpringActions.OUTSIDE_OF_CONFINES] = SpringFramework.handleOutsideOfConfines(spring);
	
	if (spring.actionsPerformed and not spring.actionsPerformed[SpringFramework.SpringActions.OUTSIDE_OF_CONFINES]) then
		spring.actionsPerformed[SpringFramework.SpringActions.MOVE_INTO_ALIGNMENT] = SpringFramework.moveLockedObjectsIntoAlignment(spring);
		
		if (not spring.actionsPerformed[SpringFramework.SpringActions.MOVE_INTO_CONFINES]) then
			spring.actionsPerformed[SpringFramework.SpringActions.APPLY_FORCES] = SpringFramework.applyForcesToObjects(spring);
		end
	end
end

function SpringFramework.handleOutsideOfConfines(spring)
	local actionsPerformed = false;
	local isOutsideOfConfines;
	
	for i = 1, 2 do
		if (spring.outsideOfConfinesAction[i].type ~= SpringFramework.OutsideOfConfinesOptions.DO_NOTHING) then
			isOutsideOfConfines = {
				min = spring.confinesToCheck.min == true and ((i == 1 and spring.unrotatedDistances[i].min.X > spring.minimumValuesForActions[SpringFramework.SpringActions.OUTSIDE_OF_CONFINES]) or (i == 2 and spring.unrotatedDistances[i].min.X < -spring.minimumValuesForActions[SpringFramework.SpringActions.OUTSIDE_OF_CONFINES])),
				max = spring.confinesToCheck.max == true and ((i == 1 and spring.unrotatedDistances[i].max.X < -spring.minimumValuesForActions[SpringFramework.SpringActions.OUTSIDE_OF_CONFINES]) or (i == 2 and spring.unrotatedDistances[i].max.X > spring.minimumValuesForActions[SpringFramework.SpringActions.OUTSIDE_OF_CONFINES])),
				absolute = spring.confinesToCheck.absolute == true and (spring.distances[i].rest.Magnitude > (spring.length.difference + spring.minimumValuesForActions[SpringFramework.SpringActions.OUTSIDE_OF_CONFINES]))
			};
			
			if (isOutsideOfConfines.min or isOutsideOfConfines.max or isOutsideOfConfines.absolute) then
				if (showDebug == true) then
					local debugString = isOutsideOfConfines.min and "< MIN" or (isOutsideOfConfines.max and "> MAX" or "");
					debugString = debugString..(isOutsideOfConfines.absolute and (debugString.string.len() > 0 and " & > ABS" or "> ABS") or "").." Confines";
					print(debugString);
					ToGameActivity(ActivityMan:GetActivity()):AddObjectivePoint(debugString, spring.targetPos[i], Activity.TEAM_1, GameActivity.ARROWDOWN);
				end
				
				if (spring.outsideOfConfinesAction[i].type == SpringFramework.OutsideOfConfinesOptions.BREAK_SPRING) then
					for k in pairs(spring) do
						spring[k] = nil;
					end
					return true;
				elseif (spring.outsideOfConfinesAction[i].type == SpringFramework.OutsideOfConfinesOptions.MOVE_TO_REST_POSITION) then
					spring.targets[i].Pos = spring.pos[i].rest;
					spring.targets[i]:ClearForces();
					actionsPerformed = true;
				elseif (spring.outsideOfConfinesAction[i].type == SpringFramework.OutsideOfConfinesOptions.CALLBACK) then
					actionsPerformed = spring.outsideOfConfinesAction[i].callback(spring, isOutsideOfConfines);
				end
			end
		end
	end
	
	if (actionsPerformed) then
		SpringFramework.updateCalculations(spring);
	end
	return actionsPerformed;
end

--TODO For the tank at least, we need a lot of horizontal force on object 1 to stop it from moving when the wheel doesn't align. However we don't want this
function SpringFramework.moveLockedObjectsIntoAlignment(spring)
	local actionsPerformed = false, unrotatedVel, forceVector;
	
	for i = 1, 2 do
		if (not spring.targetIsVector[i]) then
			if (spring.lockToSpringRotation == true or spring.lockToSpringRotation == i) then
				
				--Lock travel impulse to spring alignment
				if (spring.targets[i].TravelImpulse.Magnitude > 0) then
					local unrotatedTravelImpulse = spring.targets[i].TravelImpulse:RadRotate(-spring.rotAngle);
					spring.targets[i].TravelImpulse = Vector(unrotatedTravelImpulse.X, 0):RadRotate(spring.rotAngle);
					
					actionsPerformed = true;
				end

				if (spring.unrotatedDistances[i].rest.Y >= spring.minimumValuesForActions[SpringFramework.SpringActions.MOVE_INTO_ALIGNMENT]) then
					--TODO add check wherein if distance is too far (set some default based on the spring's length) we reset it completely
				
					unrotatedVel = Vector(spring.targets[i].Vel.X, spring.targets[i].Vel.Y):RadRotate(-spring.rotAngle);
					forceVector = Vector(0, (-unrotatedVel.Y - spring.unrotatedDistances[i].rest.Y)):RadRotate(spring.rotAngle);
					spring.targets[i]:AddImpulseForce(forceVector, spring.applyForcesAtOffset and spring.rotatedOffsets[i] * FrameMan.MPP or Vector(0, 0));
					
					--if (spring.showDebug and i == 2) then
					--	print("rotAngle: "..tostring(spring.rotAngle * 180 / math.pi)..", unrotatedDistance: "..tostring(spring.unrotatedDistances[i].rest)..", vel: "..tostring(spring.targets[i].Vel)..", unrotatedVel: "..tostring(unrotatedVel));
					--end
				
					if (spring.showDebug == true) then
						local maxForceStrength = spring.length.difference + 5;
						local forceLine = Vector(forceVector.X, forceVector.Y):SetMagnitude(50 * forceVector.Magnitude/maxForceStrength);
						local drawStartPos =  spring.applyForcesAtOffset and spring.targetPos[i] or spring.targets[i].Pos;
						SpringFramework.drawArrow(drawStartPos, drawStartPos + forceLine, spring.drawAngle, 7, forceVector.Magnitude >= maxForceStrength and 254 or 5);
					end
					
					actionsPerformed = true;
				end
			else
				--TODO support unlocked springs
			end
		end
	end
	
	if (actionsPerformed) then
		SpringFramework.updateCalculations(spring);
	end
	return actionsPerformed;
end

function SpringFramework.applyForcesToObjects(spring)
	local actionsPerformed = false;
	
	for i = 1, 2 do
		if (not spring.targetIsVector[i] and spring.distances[i].rest.Magnitude > spring.minimumValuesForActions[SpringFramework.SpringActions.APPLY_FORCES]) then
			spring.targets[i]:AddForce(spring.forceVectors[i], spring.applyForcesAtOffset and spring.rotatedOffsets[i] * FrameMan.MPP or Vector(0, 0));
			actionsPerformed = true;
			
			if (spring.showDebug == true) then
				local maxForceStrength = spring.maxForceStrength[i];
				local forceLine = Vector(spring.forceVectors[i].X, spring.forceVectors[i].Y):SetMagnitude(50 * spring.forceVectors[i].Magnitude/maxForceStrength);
				local drawStartPos =  spring.applyForcesAtOffset and spring.targetPos[i] or spring.targets[i].Pos;
				SpringFramework.drawArrow(drawStartPos, drawStartPos + forceLine, spring.drawAngle, 7, spring.forceVectors[i].Magnitude >= maxForceStrength and 254 or 0);
			end
		end
	end
	
	return actionsPerformed;
end

function SpringFramework.drawDebugLines(spring)
	for i = 1, 2 do
		for j = -1, 1 do
			PrimitiveMan:DrawLinePrimitive(spring.pos.mid + Vector(-9, j):RadRotate(spring.drawAngle), spring.pos.mid + Vector(9, j):RadRotate(spring.drawAngle), 5);
		
			PrimitiveMan:DrawLinePrimitive(spring.pos[i].min + Vector(-3, j):RadRotate(spring.drawAngle), spring.pos[i].min + Vector(3, j):RadRotate(spring.drawAngle), 5);
			PrimitiveMan:DrawLinePrimitive(spring.pos[i].rest + Vector(-3, j):RadRotate(spring.drawAngle), spring.pos[i].rest + Vector(3, j):RadRotate(spring.drawAngle), 5);
			PrimitiveMan:DrawLinePrimitive(spring.pos[i].max + Vector(-3, j):RadRotate(spring.drawAngle), spring.pos[i].max + Vector(3, j):RadRotate(spring.drawAngle), 5);
		end
		PrimitiveMan:DrawLinePrimitive(spring.targetPos[i] + Vector(-15, 0):RadRotate(spring.drawAngle), spring.targetPos[i] + Vector(15, 0):RadRotate(spring.drawAngle), 151);
		PrimitiveMan:DrawLinePrimitive(spring.pos.mid + Vector(0, -spring.length.difference):RadRotate(spring.drawAngle), spring.pos.mid + Vector(0, spring.length.difference):RadRotate(spring.drawAngle), 151);
	end
end


function SpringFramework.drawArrow(startPos, endPos, rotAngle, width, colourIndex)
	local distance = SceneMan:ShortestDistance(startPos, endPos, SceneMan.SceneWrapsX);
	endPos = startPos + distance;
	local lineAngle = (distance.AbsDegAngle + 360)%360;
	local isHorizontal = (lineAngle >= 315 or lineAngle <= 45) or (lineAngle >= 135 and lineAngle <= 225);
	local isVertical = (lineAngle >= 45 and lineAngle <= 135) or (lineAngle >= 225 and lineAngle <= 315);
	local evenLineCount = width % 2 == 0;
	local midCount = math.ceil(width * 0.5);
	local rotatedStartPos = Vector(startPos.X, startPos.Y):RadRotate(-rotAngle);

	for i = 1, width + (evenLineCount and 1 or 0) do
		if (i == midCount) then
			if (evenLineCount == false) then
				PrimitiveMan:DrawLinePrimitive(startPos, endPos, colourIndex);
			end
		else
			PrimitiveMan:DrawLinePrimitive(Vector(rotatedStartPos.X - (isVertical and (midCount - i) or 0), rotatedStartPos.Y - (isHorizontal and (midCount - i) or 0)):RadRotate(rotAngle), endPos, colourIndex);
		end
	end
end