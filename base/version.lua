-- kernel version info --

do
  k._NAME = "Cynosure"
  k._RELEASE = "0" -- not released yet
  k._VERSION = "@[[os.date('%Y.%m.%d')]]"
  _G._OSVERSION = string.format("%s r%s %s", k._NAME, k._RELEASE, k._VERSION)
end