-- CFS: The Cynosure File-System --

k.log(k.loglevels.info, "extra/fs/cfs")

do
  -- haha cursed structs go brrrrr
  local superblock = struct {
    char[8] "signature",
    uint16 "block_size",
    uint64 "block_count",
    uint64 "inode_count",
    uint64 "fs_size",
    uint16 "revision"
  }
  local inode = struct {
    uint16 "permissions",
    uint16 "owner",
    uint16 "group",
    uint16 "references",
    uint64 "size",
    uint64 "create",
    uint64 "access",
    uint64 "modify",
    char[64] "padding",
    char[40*8] "datablocks",
    char[8*8] "indirect",
    char[3*8] "double_indirect"
  }
end
