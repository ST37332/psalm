local math = math

local VECTOR = FindMetaTable("Vector")

-- returns the center between the two vectors
function VECTOR:Center( vOtherVector )
	return (self + vOtherVector) / 2
end

-- Rounds all the vector components to the number of decimals points passed, default 0
function VECTOR:Round( nDecimals )
	local nDecimals = nDecimals or 0
	return Vector( math.Round( self.x, nDecimals ), math.Round( self.y, nDecimals ), math.Round( self.z, nDecimals ) )
end

-- Clamps the vector between the min and max values and returns the modified vector
function VECTOR:Clamp( vMin, vMax )
	return Vector (
		math.Clamp( self.x, vMin.x, vMax.x ),
		math.Clamp( self.y, vMin.y, vMax.y ),
		math.Clamp( self.z, vMin.z, vMax.z )
	)
end

function VECTOR:ceil()
    self.x = math.ceil( self.x )
    self.y = math.ceil( self.y )
    self.z = math.ceil( self.z )

    return self
end


-- Non-Metamethods. Just standard Vector calls.

-- When passed two bounding box vectors (min and max) it will return all corners of the box
function VECTOR.BoxCorners( vMin, vMax )
	return {
		vMin,
		Vector( vMin.x, vMin.y, vMax.z ),
		Vector( vMin.x, vMax.y, vMin.z ),
		Vector( vMin.x, vMax.y, vMax.z ),
		vMax,
		Vector( vMax.x, vMax.y, vMin.z ),
		Vector( vMax.x, vMin.y, vMax.z ),
		Vector( vMax.x, vMin.y, vMin.z )
	}
end

-- Given a table of vectors this will return a single vector with the max x,y,z components found in the table of vectors.
-- I.e if you passed (1000, -50, 45), (200, 200, 200) it would return Vector( 1000, 200, 200 )
function VECTOR.Max( tVectors )

	local x = -9000000
	local y = -9000000
	local z = -9000000

	for i = 1, #tVectors do
		local vCurrent = tVectors[ i ]
		x = vCurrent.x > x and vCurrent.x or x
		y = vCurrent.y > y and vCurrent.y or y
		z = vCurrent.z > z and vCurrent.z or z
	end

	return Vector( x, y, z )
end

-- Given a table of vectors this will return a single vector with the min x,y,z components found in the table of vectors.
-- I.e if you passed (1000, -50, 45), (200, 200, 200) it would return Vector( 200, -50, 45 )
function VECTOR.Min( tVectors )

	local x = 9000000
	local y = 9000000
	local z = 9000000

	for i = 1, #tVectors do
		local vCurrent = tVectors[ i ]
		x = vCurrent.x < x and vCurrent.x or x
		y = vCurrent.y < y and vCurrent.y or y
		z = vCurrent.z < z and vCurrent.z or z
	end

	return Vector( x, y, z )
end
