local QB = {}
QB.__index = QB

function QB:New(driver)
    return setmetatable({
        driver = driver,
        type = "SELECT",
        table = nil,
        fields = {"*"},
        joins = {},
        where = {},
        params = {},
        limit = nil,
        offset = nil,
        orderBy = nil
    }, self)
end

function QB:Reset()
    self.type = "SELECT"
    self.table = nil
    self.fields = {"*"}
    self.joins = {}
    self.where = {}
    self.params = {}
    self.limit = nil
    self.offset = nil
    self.orderBy = nil
    return self
end

function QB:Select(tableName)
    self:Reset()
    self.type = "SELECT"
    self.table = tableName
    return self
end

function QB:Insert(tableName)
    self:Reset()
    self.type = "INSERT"
    self.table = tableName
    self.data = {}
    return self
end

function QB:Update(tableName)
    self:Reset()
    self.type = "UPDATE"
    self.table = tableName
    self.data = {}
    return self
end

function QB:Delete(tableName)
    self:Reset()
    self.type = "DELETE"
    self.table = tableName
    return self
end

function QB:Fields(...)
    self.fields = {...}
    return self
end

function QB:Where(key, value)
    table.insert(self.where, string.format("`%s` = ?", key))
    table.insert(self.params, value)
    return self
end

function QB:WhereIn(key, values)
    local placeholders = {}
    for i = 1, #values do
        table.insert(placeholders, "?")
        table.insert(self.params, values[i])
    end
    table.insert(self.where, string.format("`%s` IN (%s)", key, table.concat(placeholders, ", ")))
    return self
end

function QB:Set(data)
    self.data = data
    return self
end

function QB:Limit(count)
    self.limit = count
    return self
end

function QB:Offset(off)
    self.offset = off
    return self
end

function QB:OrderBy(key, dir)
    self.orderBy = {key, dir or "ASC"}
    return self
end

function QB:Build()
    local sql = ""
    if self.type == "SELECT" then
        sql = string.format("SELECT %s FROM `%s`", table.concat(self.fields, ", "), self.table)
        if #self.where > 0 then
            sql = sql .. " WHERE " .. table.concat(self.where, " AND ")
        end
        if self.orderBy then
            sql = sql .. string.format(" ORDER BY `%s` %s", self.orderBy[1], self.orderBy[2])
        end
        if self.limit then
            sql = sql .. " LIMIT " .. self.limit
            if self.offset then sql = sql .. " OFFSET " .. self.offset end
        end
    elseif self.type == "INSERT" then
        local keys, vals = {}, {}
        for k, v in pairs(self.data) do
            table.insert(keys, string.format("`%s`", k))
            table.insert(vals, "?")
            table.insert(self.params, v)
        end
        sql = string.format("INSERT INTO `%s` (%s) VALUES (%s)", self.table, table.concat(keys, ", "), table.concat(vals, ", "))
    elseif self.type == "UPDATE" then
        local sets = {}
        for k, v in pairs(self.data) do
            table.insert(sets, string.format("`%s` = ?", k))
            table.insert(self.params, v)
        end
        sql = string.format("UPDATE `%s` SET %s", self.table, table.concat(sets, ", "))
        if #self.where > 0 then sql = sql .. " WHERE " .. table.concat(self.where, " AND ") end
    elseif self.type == "DELETE" then
        sql = string.format("DELETE FROM `%s`", self.table)
        if #self.where > 0 then sql = sql .. " WHERE " .. table.concat(self.where, " AND ") end
    end
    return sql
end

function QB:Execute(callback)
    local sql = self:Build()
    self.driver:Queue(sql, self.params, callback)
    return self
end

local FACTORY = {}
FACTORY.__index = FACTORY

function FACTORY:New(driver)
    return setmetatable({driver = driver}, FACTORY)
end

function FACTORY:NewQuery()
    return QB:New(self.driver)
end

return FACTORY