-- kernel version info --

do
  k._NAME = "Cynosure"
  k._RELEASE = "@[{tostring(env.KRELEASE or os.getenv('KRELEASE') or 1.03)}]"
  k._VERSION = "@[{os.date('%Y.%m.%d') .. '-' .. (env.KCUSTOMNAME or os.getenv('KCUSTOMNAME') or 'default')}]"
  _G._OSVERSION = string.format("%s r%s-%s", k._NAME, k._RELEASE, k._VERSION)
end
