-- fairly efficient binary structs
-- note that to make something unsigned you ALWAYS prefix the type def with
-- 'u' rather than 'unsigned ' due to Lua syntax limitations.
-- ex:
-- local example = struct {
--   uint16("field_1"),
--   string[8]("field_2")
-- }
-- local copy = example "\0\14A string"

k.log(k.loglevels.info, "ksrc/struct")

do
  -- step 1: change the metatable of _G so we can have convenient type notation
  -- without technically cluttering _G
  local gmt = {}
  
  local types = {
    int = "i",
    uint = "I",
    bool = "b", -- currently booleans are just signed 8-bit values because reasons
    short = "h",
    ushort = "H",
    long = "l",
    ulong = "L",
    size_t = "T",
    float = "f",
    double = "d",
    lpstr = "s",
  }

  -- char is a special case:
  --   - the user may want a single byte (char("field"))
  --   - the user may also want a fixed-length string (char[42]("field"))
  local char = {}
  setmetatable(char, {
    __call = function(field)
      return {fmtstr = "B", field = field}
    end,
    __index = function(t, k)
      if type(k) == "number" then
        return function(value)
          return {fmtstr = "c" .. k, field = value}
        end
      else
        error("invalid char length specifier")
      end
    end
  })

  function gmt.__index(t, k)
    if k == "char" then
      return char
    else
      local tp
      for t, v in pairs(types) do
        local match = k:match("^"..t)
        if match then tp = t break end
      end
      if not tp then return nil end
      return function(value)
        return {fmtstr = types[tp] .. tonumber(k:match("%d+$") or "0")//8,
          field = value}
      end
    end
  end

  -- step 2: change the metatable of string so we can have string length
  -- notation.  Note that this requires a null-terminated string.
  local smt = {}

  function smt.__index(t, k)
    if type(k) == "number" then
      return function(value)
        return {fmtstr = "z", field = value}
      end
    end
  end

  -- step 3: apply these metatable hacks
  setmetatable(_G, gmt)
  setmetatable(string, smt)

  -- step 4: ???

  -- step 5: profit

  function struct(fields, name)
    checkArg(1, fields, "table")
    checkArg(2, name, "string", "nil")
    local pat = "<"
    local args = {}
    for i=1, #fields, 1 do
      local v = fields[i]
      pat = pat .. v.fmtstr
      args[i] = v.field
    end
  
    return setmetatable({}, {
      __call = function(_, data)
        assert(type(data) == "string" or type(data) == "table",
          "bad argument #1 to struct constructor (string or table expected)")
        if type(data) == "string" then
          local set = table.pack(string.unpack(pat, data))
          local ret = {}
          for i=1, #args, 1 do
            ret[args[i]] = set[i]
          end
          return ret
        elseif type(data) == "table" then
          local set = {}
          for i=1, #args, 1 do
            set[i] = data[args[i]]
          end
          return string.pack(pat, table.unpack(set))
        end
      end,
      __len = function()
        return string.packsize(pat)
      end,
      __name = name or "struct"
    })
  end

end
