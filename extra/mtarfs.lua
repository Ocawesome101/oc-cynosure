-- mtarfs support --

k.log(k.loglevels.info, "extra/mtarfs")

if k.cmdline.root == "mtar" then
  if not __mtar_fs_tree then
    k.panic("mtar fs tree not available")
  end
  k.log(k.loglevels.info, "mounting mtarfs as rootfs")
  k.fs.api.mount(__mtar_fs_tree, k.fs.types.NODE, "/")
end
