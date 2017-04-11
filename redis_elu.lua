-- redis-expire-least-used
-- Author: Gabriel Bordeaux (gabfl)
-- Github: https://github.com/gabfl/redis-expire-least-used
-- Version: 1.0
-- (can only be used in 3.2+)

redis.replicate_commands()

-- Get mandatory vars
local action = ARGV[1];

-- Define misc vars
local expirationList = 'pex|all'

-- returns true if empty or null
-- http://stackoverflow.com/a/19667498/50501
local function isempty(s)
  return s == nil or s == '' or type(s) == 'userdata'
end

-- Returns current timestamp
local getTime = function()
    local t = redis.call('TIME') -- get array of unix timestamp
    return tonumber(t[1]) -- get first string from array and convert it to a number
end

-- Making sure required fields are not nil
assert(not isempty(action), 'ERR1: Action is missing')

if action == 'get'
then
    -- Define vars
    local key = ARGV[2];

    -- Making sure required fields are not nil
    assert(not isempty(key), 'ERR2: Key is missing')

    -- debug
    redis.debug('get');

    -- Remove item from sorted set
    redis.call('ZREM', expirationList, key)

    -- Return item
    return redis.call('GET', key)
elseif action == 'set'
then
    -- debug
    redis.debug('set');

    -- Define vars
    local key = ARGV[2];
    local value = ARGV[3];
    local expiration = ARGV[4];
    local preExpiration = ARGV[5];

    -- Making sure required fields are not nil
    assert(not isempty(key), 'ERR2: Key is missing')
    assert(not isempty(value), 'ERR3: Value is missing')
    assert(not isempty(expiration), 'ERR4: Expiration is missing')
    assert(not isempty(preExpiration), 'ERR5: Pre expiration is missing')

    -- Set pre expiration timestamp
    preExpiration = preExpiration + getTime()

    -- Add to sorted set
     redis.call('ZADD', expirationList, 'NX', preExpiration, key)

     -- Set the object
     return redis.call("SETEX", key, expiration, value)
elseif action == 'expire'
then
    -- debug
    redis.debug('expire');

    -- Define vars
    local limit = ARGV[2] or nil;

    -- Get items to expire
    local list
    if limit then
        -- debug
        redis.debug('...expire items -> '..limit);

        list = redis.call('ZRANGEBYSCORE', expirationList, 0, getTime(), 'LIMIT', 0, limit)
    else
        list = redis.call('ZRANGEBYSCORE', expirationList, 0, getTime())
    end

    -- count items
    local listCount = table.getn(list);

    -- debug
    redis.debug('...going to delete items -> '..listCount);

    -- If we have items to expire
    if listCount ~= 0
    then
        -- for i,table.getN(list) do
        for i=1,listCount do
            -- Delete item
            redis.call('DEL', list[i])

            -- debug
            redis.debug('...deleting key -> '..list[i]);
        end

        -- Remove deleted items
        redis.call('ZREMRANGEBYRANK', expirationList, 0, listCount - 1)
    end

    return listCount;
else
    error('ERR2: Invalid action.')
end
