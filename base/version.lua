-- kernel version info --

do
  k._NAME = "Cynosure"
  k._RELEASE = "1.02"
  k._VERSION = "@[{os.date('%Y.%m.%d')}]"
  _G._OSVERSION = string.format("%s r%s-%s", k._NAME, k._RELEASE, k._VERSION)
end
