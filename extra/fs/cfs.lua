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
  }
end
