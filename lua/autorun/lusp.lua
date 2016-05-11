if ( SERVER ) then
	
	Lusp = Lusp or {}
	Lusp.__index = Lusp
	
	local TYPES = {
		SYMBOL    = 1,
		NUMBER    = 2,
		LIST      = 4,
		PROCEDURE = 8,
		BOOLEAN   = 16,
	}
	Lusp.TYPES = TYPES
	
	local TRUE  = "t"
	local FALSE = "nil"
	
	function Lusp:tostring( cons )
		if ( cons.type == self.TYPES.LIST ) then
			if ( not cons.list ) then return cons.value end
			local str = "("
			for k, v in ipairs( cons.list ) do
				str = str .. self:tostring( v ).. (k < #cons.list and " " or "")						
			end
			str = str .. ")"
			return str
		else
			return cons.value
		end
	end
	
	function Lusp:Cons( type, value, list, env, func )
		return {
			value = value,
			type  = type,
			list  = list or {},
			env   = env  or {},
			func  = func or nil,
		}
	end

	function Lusp:Env( params, args, outer )
		local env = {}

		if ( params and args ) then
			for i = 1, #params do
				env[ params[i].value:lower() ] = args[i]
			end
		end
		env.find = function( v ) return (env[v:lower()] and env) or (outer and outer.find( v ) and outer) end
		return env
	end
	
	function Lusp:tokenize( str )
		return string.Explode( "%s+", str:Replace( "(", " ( " ):Replace( ")", " ) " ):Trim(), true )
	end

	function Lusp:construct( tokens )
		if ( #tokens == 0 ) then return end
		
		local token = table.remove( tokens, 1 )
	
		if ( token == "(" ) then
			local cons = self:Cons( TYPES.LIST )
			while ( tokens[1] ~= ")" ) do
				table.insert( cons.list, self:construct( tokens ) )
			end
			
			if ( #tokens == 0 ) then error( "Missing matching right parenthesis ')'" ) end
			
			table.remove( tokens, 1 )
			return cons
			
		elseif ( token == ")" ) then error( "Unexpected right parenthesis ')'" )
		else
			if ( tonumber( token ) ) then
				return self:Cons( self.TYPES.NUMBER, tonumber( token ) )
			else
				return self:Cons( self.TYPES.SYMBOL, token:lower() )
			end
		end
	end
	
	function Lusp:parse( str )
		return self:construct( self:tokenize( str ) )
	end
	
	
	Lusp._g_env = Lusp:Env()
	function Lusp:setup()
		self._g_env['=']  = self:Cons( self.TYPES.PROCEDURE, '=',  nil, nil, function( objs ) return self:Cons( self.TYPES.BOOLEAN, objs[1].value == objs[2].value and TRUE or FALSE ) end )
		self._g_env['+']  = self:Cons( self.TYPES.PROCEDURE, '+',  nil, nil, function( objs ) return self:Cons( self.TYPES.NUMBER, objs[1].value  + objs[2].value ) end )
		self._g_env['-']  = self:Cons( self.TYPES.PROCEDURE, '-',  nil, nil, function( objs ) return self:Cons( self.TYPES.NUMBER, objs[1].value  - objs[2].value ) end )
		self._g_env['*']  = self:Cons( self.TYPES.PROCEDURE, '*',  nil, nil, function( objs ) return self:Cons( self.TYPES.NUMBER, objs[1].value  * objs[2].value ) end )
		self._g_env['/']  = self:Cons( self.TYPES.PROCEDURE, '/',  nil, nil, function( objs ) return objs[2].value == 0 and 0 or self:Cons( self.TYPES.NUMBER, objs[1].value  / objs[2].value )	end )
		self._g_env['>']  = self:Cons( self.TYPES.PROCEDURE, '>',  nil, nil, function( objs ) return self:Cons( self.TYPES.BOOLEAN, objs[1].value  > objs[2].value and TRUE or FALSE ) end )
		self._g_env['<']  = self:Cons( self.TYPES.PROCEDURE, '<',  nil, nil, function( objs ) return self:Cons( self.TYPES.BOOLEAN, objs[1].value  < objs[2].value and TRUE or FALSE ) end )
		self._g_env['>='] = self:Cons( self.TYPES.PROCEDURE, '>=', nil, nil, function( objs ) return self:Cons( self.TYPES.BOOLEAN, objs[1].value >= objs[2].value and TRUE or FALSE ) end )
		self._g_env['<='] = self:Cons( self.TYPES.PROCEDURE, '<=', nil, nil, function( objs ) return self:Cons( self.TYPES.BOOLEAN, objs[1].value <= objs[2].value and TRUE or FALSE ) end )
		
		self._g_env[FALSE] = self:Cons( self.TYPES.BOOLEAN, FALSE )
		self._g_env[TRUE]  = self:Cons( self.TYPES.BOOLEAN, TRUE )
		
		self._g_env['pi']   = self:Cons( self.TYPES.SYMBOL, math.pi )
		self._g_env['car']  = self:Cons( self.TYPES.PROCEDURE, 'car',  nil, nil, function( objs )
			if ( objs[1].type ~= self.TYPES.LIST ) then error( "Argument must be a list" ) end
			return objs[1].list and objs[1].list[1] or self:Cons( self.TYPES.BOOLEAN, FALSE )
		end )
		self._g_env['cdr']  = self:Cons( self.TYPES.PROCEDURE, 'cdr',  nil, nil, function( objs )
			if ( objs[1].type ~= self.TYPES.LIST ) then error( "Argument must be a list" ) end
			table.remove( objs[1].list, 1 )
			return objs[1]
		end )
		self._g_env['list'] = self:Cons( self.TYPES.PROCEDURE, 'list', nil, nil, function( objs ) 
			local cons = self:Cons( self.TYPES.LIST )
			for k, v in ipairs( objs ) do
				table.insert( cons.list, v )
			end
			return cons
		end )
		self._g_env['cons'] = self:Cons( self.TYPES.PROCEDURE, 'cons', nil, nil, function( objs )
			local cons = self:Cons( self.TYPES.LIST )
			for k, v in pairs( objs ) do
				if ( v.type == self.TYPES.LIST ) then
					for j, w in pairs( v.list ) do
						table.insert( cons.list, w )
					end
				else
					table.insert( cons.list, v )
				end
			end
			
			return cons
		end )
		self._g_env['sqrt']  = self:Cons( self.TYPES.PROCEDURE, 'sqrt',  nil, nil, function( objs ) return self:Cons( self.TYPES.NUMBER, math.sqrt( objs[1].value ) ) end )
		self._g_env['eq']    = self:Cons( self.TYPES.PROCEDURE, 'eq',    nil, nil, function( objs ) return self:Cons( self.TYPES.BOOLEAN, objs[1] == objs[2] and TRUE or FALSE ) end )
		self._g_env['equal'] = self:Cons( self.TYPES.PROCEDURE, 'equal', nil, nil, function( objs ) return self:Cons( self.TYPES.BOOLEAN, objs[1].value == objs[2].value and TRUE or FALSE ) end )
		self._g_env['listp'] = self:Cons( self.TYPES.PROCEDURE, 'listp', nil, nil, function( objs ) return self:Cons( self.TYPES.BOOLEAN, objs[1].type == self.TYPES.LIST and TRUE or FALSE ) end )
		self._g_env['null']  = self:Cons( self.TYPES.PROCEDURE, 'null',  nil, nil, function( objs ) return self:Cons( self.TYPES.BOOLEAN, objs[1].value == "nil" and TRUE or FALSE ) end )
		self._g_env['not']   = self:Cons( self.TYPES.PROCEDURE, 'not',   nil, nil, function( objs ) return self:Cons( self.TYPES.BOOLEAN, objs[1].value == "nil" and TRUE or FALSE ) end )
	end
	
	function Lusp:eval( obj, env, depth )
		if ( depth >= 16 ) then error( "Detected possible stack overflow" ) end
		depth = depth + 1
		
		if ( obj.type == self.TYPES.SYMBOL ) then
			
			local lenv = env.find( obj.value )
			return lenv and lenv[ obj.value ] or error( "Undefined symbol: " .. tostring( obj.value ) )
			
		elseif ( obj.type == self.TYPES.NUMBER ) then
			
			return obj
			
		elseif ( obj.type == self.TYPES.LIST ) then
			local first = obj.list[1] and obj.list[1].value
			if ( not first ) then return self:Cons( self.TYPES.BOOLEAN, FALSE ) end
			
			if ( first == "lambda" ) then
				local proc = self:Cons( self.TYPES.PROCEDURE, "lambda" )
				local params = obj.list[2].list
				local body   = obj.list[3]
				proc.env = env
				local depth = 0
				proc.func = function( args )
					return self:eval( body, self:Env( params, args, env ), depth )
				end
				
				return proc
			elseif ( first == "if" ) then
				local test   = obj.list[2]
				local conseq = obj.list[3]
				local alt    = obj.list[4]
				return self:eval( self:eval( test, env, depth ).value ~= FALSE and conseq or alt, env, depth )
			elseif ( first == "cond" ) then
				local hasDefault = false
				for k, v in ipairs( obj.list ) do
					if ( k == 1 ) then continue end
					if ( v.type ~= self.TYPES.LIST ) then error( "Argument #"..k.." needs to be a list" ) end
					if ( v.list[1] and v.list[1].value == TRUE ) then hasDefault = true end
				end
				
				if ( not hasDefault ) then error( "Unable to find default case 't'" ) end
				
				for k, v in ipairs( obj.list ) do
					if ( k == 1 ) then continue end
					local test = self:eval( v.list[1], env, depth )
					if ( test.value ~= FALSE ) then
						if ( not v.list[2] ) then
							return test
						else
							return self:eval( v.list[2], env, depth )
						end
					end
				end
				
				return self:Cons( self.TYPES.BOOLEAN, FALSE )
			elseif ( first == "define" ) then
				local var = obj.list[2].value
				local exp = obj.list[3]
				local result = self:eval( exp, env, depth )
				env[ var ] = result
				return result
			elseif ( first == "set!" ) then
				local var = obj.list[2].value
				local exp = obj.list[3]
				env.find( var )[ var ] = self:eval( exp, env, depth )
				return self:Cons( self.TYPES.BOOLEAN, FALSE )
			elseif ( first == "quote" ) then
				return obj.list[2]
			elseif ( first == "reset" ) then
				self:setup()
				return self:Cons( self.TYPES.BOOLEAN, FALSE )
			else
				local proc = self:eval( obj.list[1], env, depth )
				if ( proc.type == self.TYPES.PROCEDURE ) then
					local args = {}

					for i = 2, #obj.list do
						args[i-1] = self:eval( obj.list[i], env, depth )
					end
					return proc.func( args )
				else
					return proc
				end
			end
		else
			return obj
		end
	end

	function Lusp:run( str )
		return self:eval( self:parse( str ), self._g_env, 0 )
	end
	
	
	Lusp:setup()

end