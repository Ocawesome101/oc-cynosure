-- "live patch" support so theoretically the kernel can be upgraded in-place --
-- there are certain components that may not work

k.log(k.loglevels.info, "extra/live_patch.lua")

do
  local kernel_env = k.copy_table(_G)
  kernel_env.component = component
  kernel_env.computer = computer
  function k.livepatch(code)
    if k.security.get_permission("KERNEL_ACCESS") then
      local ok, err = load(code, "=livepatch-code", "bt", kernel_env)
      -- we run the kernel code inside the sandbox, then merge most changes
    else
      return nil, "permission denied"
    end
  end
end
