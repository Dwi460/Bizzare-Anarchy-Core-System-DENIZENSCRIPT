# =============================================================================
#  BACODKAU HARDCORE (BKHC) - FILE 1: CORE SYSTEM
#  Letakkan di: plugins/Denizen/scripts/BKHC_Core.dsc
#
#  Isi:
#    1.  config_brutal_legend      semua angka dan pesan inti
#    2.  random_tp_task, random_teleport_on_spawn   teleport acak
#    3.  death_listener, void_*    mati -> dimensi void -> teleport
#    4.  totem_listener, givetotem_command, totemevent_command   totem
#    5.  mendingvillager_listener, fishing_mending_listener   mending
#    6.  hide_nametag_listener, local_chat_listener   nametag & chat radius
#    7.  gameplay_handler          ancient debris, pesan join/quit
#    8.  frisk_*                   penggeledahan (menu, aman Bedrock)
#    9.  stack_golden_apple, item_cooldown, mace_cooldown, disable_explode
#   10.  compass_handler, tab_*    kompas dan tab list
# =============================================================================


# =============================================================================
#  1. CONFIG
# =============================================================================
config_brutal_legend:
    type: data
    rtp location: "5000"
    world border: "10000"
    rtp world name: "world"
    rtp max attempts: "10"
    rtp protect duration: "20s"
    compass target: "100000,100,100000,world"
    void world name: "void"
    void spawn: "0,100,0"
    void base minutes: "5"
    void extra minutes: "5"
    chat radius: "8"
    max stack golden apple: "12"
    ender pearl cooldown: "10s"
    trident cooldown: "30s"
    mending fishing chance: "20"
    mending villager chance: "50"
    message:
        prefix: "<&4><&l>BacodKau HC <&5>/"
        disable chat: "<&4>Chat Disable"
        mati: "Anda telah mati"
        req inventory: "<&f>Kamu telah mengirimkan izin untuk penggeledahan"
        reject req inventory: "<&f>Penggeledahan ditolak"
        get req inventory:
            1: "<&f>Kamu ingin digeledah. Apakah kamu mengizinkannya"
            2: "IYA"
            3: "TIDAK"


# =============================================================================
#  2. TELEPORT ACAK
# =============================================================================
random_tp_task:
    type: task
    debug: false
    script:
    - define cfg <script[config_brutal_legend]>
    - define world <[cfg].data_key[rtp world name]>
    - define wt <world[<[world]>]>
    - define protect <[cfg].data_key[rtp protect duration]>
    - cast RESISTANCE duration:<[protect]> amplifier:100 hide_particles no_icon no_ambient
    - define range <[cfg].data_key[rtp location]>
    - define half <[wt].border_size.div[2].sub[100].round_down>
    - if <[half]> < <[range]>:
        - define range <[half]>
    - define cx <[wt].border_center.x>
    - define cz <[wt].border_center.z>
    - wait 1s
    - stop if:!<player.is_online>
    - define found false
    - repeat <[cfg].data_key[rtp max attempts]>:
        - define x <util.random.int[-<[range]>].to[<[range]>].add[<[cx]>]>
        - define z <util.random.int[-<[range]>].to[<[range]>].add[<[cz]>]>
        - define spot <location[<[x]>,100,<[z]>,<[world]>]>
        - chunkload <[spot].chunk> duration:1m
        - define ground <[spot].highest>
        - define bad_ground <list[magma_block|cactus|campfire|soul_campfire].contains[<[ground].material.name>]>
        - define bad_above <list[water|lava|fire|soul_fire|powder_snow|cactus].contains[<[ground].above.material.name>]>
        - if <[ground].y> > 0 && <[bad_ground]> == false && <[bad_above]> == false:
            - define found true
            - repeat stop
    - if <[found]>:
        - define target <[ground].above[2].add[0.5,0,0.5]>
    - else:
        - define target <[wt].spawn_location>
    - teleport <player> <[target]>
    - adjust <player> fall_distance:0
    - cast RESISTANCE duration:<[protect]> amplifier:100 hide_particles no_icon no_ambient
    - announce to_console "[RTP] <player.name> -> <[target].simple> (found=<[found]>)"

random_teleport_on_spawn:
    type: world
    debug: false
    events:
        after player joins:
        - if !<player.has_flag[ulang]>:
            - flag <player> death:!
            - flag <player> ulang
        - if !<player.has_flag[first]>:
            - flag <player> first
            - run random_tp_task
        - else if <player.has_flag[in_void]>:
            - run void_enter
        - else if <player.has_flag[need_tp]> && <player.health> > 0:
            - run void_release
        - compass <script[config_brutal_legend].data_key[compass target]>
        after player respawns:
        - if <player.has_flag[in_void]>:
            - run void_enter
        - else if <player.has_flag[need_tp]>:
            - run void_release


# =============================================================================
#  3. KEMATIAN -> VOID
# =============================================================================
death_listener:
    type: world
    debug: false
    events:
        after player death:
        - define cfg <script[config_brutal_legend]>
        - flag <player> death:++
        - define deaths <player.flag[death]>
        - if <proc[event_active].context[void_maintenance|<player>]>:
            - define minutes 1
        - else:
            - define minutes <[cfg].data_key[void base minutes].add[<[deaths].sub[1].mul[<[cfg].data_key[void extra minutes]>]>]>
        - flag <player> in_void expire:<[minutes]>m
        - flag <player> void_total:<[minutes].mul[60]>
        - flag <player> need_tp
        - announce to_console "[DEATH] <player.name> <player.location.simple> | <context.message> | void <[minutes]> menit"
        - narrate "Kamu mati! Selamat menunggu di void selama <[minutes]> menit"
        - if !<server.has_flag[first]>:
            - flag server first
            - announce "<&4><&l>BKHC<&e><&l>/ <&f><player.name> AWKAOWKAOK mati, cupu banget. Silahkan tunggu <[minutes]> menit di Void"

void_enter:
    type: task
    debug: false
    script:
    - wait 1s
    - stop if:!<player.is_online>
    - if <player.health> <= 0:
        - stop
    - define cfg <script[config_brutal_legend]>
    - define vworld <[cfg].data_key[void world name]>
    - if <server.worlds.parse[name].contains[<[vworld]>]>:
        - define parts <[cfg].data_key[void spawn].split[,]>
        - teleport <player> <location[<[parts].get[1]>,<[parts].get[2]>,<[parts].get[3]>,<[vworld]>]>
    - else:
        - flag <player> void_fallback
        - adjust <player> gamemode:spectator
    - run void_wait_task

void_wait_task:
    type: task
    debug: false
    script:
    - if <player.has_flag[void_loop]>:
        - stop
    - define id void_<player.uuid>
    - while <player.is_online> && <player.has_flag[in_void]>:
        - flag <player> void_loop expire:3s
        - define left <player.flag_expiration[in_void].from_now>
        - define total <player.flag[void_total].if_null[600]>
        - define progress <[left].in_seconds.div[<[total]>]>
        - if <[progress]> > 1:
            - define progress 1
        - bossbar <[id]> players:<player> "title:<&b>⚡Void <&8>- <&f><[left].formatted>" progress:<[progress]> color:blue
        - wait 1s
    - bossbar remove <[id]> players:<player>
    - flag <player> void_loop:!
    - if <player.is_online> && !<player.has_flag[in_void]>:
        - run void_release

void_release:
    type: task
    debug: false
    script:
    - flag <player> need_tp:!
    - flag <player> in_void:!
    - flag <player> void_total:!
    - if <player.has_flag[void_fallback]>:
        - flag <player> void_fallback:!
        - adjust <player> gamemode:survival
    - define bed <player.bed_spawn||null>
    - if <[bed]> != null:
        - teleport <player> <[bed]>
    - else:
        - run random_tp_task


# =============================================================================
#  4. TOTEM
# =============================================================================
totem_listener:
    type: world
    debug: false
    events:
        on evoker death:
        - if <server.has_flag[totem_event]>:
            - define keep <list>
            - foreach <context.drops> as:drop:
                - if <[drop]> !matches totem_of_undying:
                    - define keep:->:<[drop]>
            - define limit <server.flag[totem_event_limit]||0>
            - define count <server.flag[totem_event_count]||0>
            - if <[limit]> == 0 || <[count]> < <[limit]>:
                - if <util.random.int[1].to[10000]> <= <server.flag[totem_event].mul[100]>:
                    - define count <[count].add[1]>
                    - flag server totem_event_count:<[count]>
                    - define keep:->:<item[totem_of_undying]>
                    - announce to_console "[TOTEMEVENT] totem jatuh (<[count]>/<[limit]>)"
                    - if <[limit]> > 0 && <[count]> >= <[limit]>:
                        - flag server "totem_event_reason:batas totem tercapai"
                        - flag server totem_event:!
                        - run totem_event_finish
            - if <[keep].is_empty>:
                - determine no_drops
            - else:
                - determine <[keep]>
        on server start:
        - if <server.has_flag[totem_event_started]>:
            - run totem_event_watch
        on reload scripts:
        - if <server.has_flag[totem_event_started]>:
            - run totem_event_watch

givetotem_command:
    type: command
    name: givetotem
    debug: false
    description: Memberi Totem of Undying kepada pemain.
    usage: /givetotem pemain [jumlah]
    permission: brutal.totem.give
    permission message: <&c>Kamu tidak punya izin untuk ini (<[permission]>).
    script:
    - define target <server.match_player[<context.args.get[1]||>]||null>
    - if <[target]> == null:
        - narrate "<&c>Pemain tidak ditemukan. Pakai: /givetotem pemain [jumlah]"
        - stop
    - define amount <context.args.get[2]||1>
    - if !<[amount].is_integer> || <[amount]> < 1 || <[amount]> > 64:
        - narrate "<&c>Jumlah harus angka 1 sampai 64."
        - stop
    - give totem_of_undying quantity:<[amount]> to:<[target].inventory>
    - narrate "<&a>Memberi <[amount]> Totem of Undying ke <[target].name>."
    - narrate "<&a>Kamu menerima <[amount]> Totem of Undying dari admin." targets:<[target]>
    - announce to_console "[TOTEM] <player.name||console> memberi <[amount]> totem ke <[target].name>"
    - announce "<&a>[Berkah Dewa] <[target].name> mendapat berkah berupa <[amount]> totem"

totem_event_watch:
    type: task
    debug: false
    script:
    - if <server.has_flag[totem_watch]>:
        - stop
    - while <server.has_flag[totem_event_started]>:
        - flag server totem_watch expire:15s
        - if !<server.has_flag[totem_event]>:
            - run totem_event_finish
        - wait 5s
    - flag server totem_watch:!

totem_event_finish:
    type: task
    debug: false
    script:
    - if !<server.has_flag[totem_event_started]>:
        - stop
    - define total <server.flag[totem_event_count]||0>
    - define reason <server.flag[totem_event_reason]||null>
    - if <[reason]> == null:
        - define reason "waktu habis"
    - flag server totem_event_started:!
    - flag server totem_event:!
    - flag server totem_event_count:!
    - flag server totem_event_limit:!
    - flag server totem_event_reason:!
    - announce "<&6>[Berkah Dewa] <&e>Event Totem selesai (<[reason]>). Total totem terkumpul: <&f><[total]><&e>."
    - announce to_console "[TOTEMEVENT] selesai (<[reason]>), total totem: <[total]>"

totemevent_command:
    type: command
    name: totemevent
    debug: false
    description: Memulai event totem: evoker menjatuhkan totem dengan peluang tertentu.
    usage: /totemevent chance waktu [batas] | stop | status
    permission: brutal.totem.event
    permission message: <&c>Kamu tidak punya izin untuk ini (<[permission]>).
    script:
    - define sub <context.args.get[1]||status>
    - if <[sub]> == status:
        - if !<server.has_flag[totem_event]>:
            - narrate "<&7>Tidak ada Event Totem yang berjalan."
            - stop
        - define left <server.flag_expiration[totem_event].from_now.formatted>
        - define limit <server.flag[totem_event_limit]||0>
        - define count <server.flag[totem_event_count]||0>
        - define limit_text <[limit]>
        - if <[limit]> == 0:
            - define limit_text "tanpa batas"
        - narrate "<&6>Event Totem: <&e><server.flag[totem_event]>% <&7>| sisa <&f><[left]> <&7>| totem <&f><[count]>/<[limit_text]>"
        - stop
    - if <[sub]> == stop:
        - if !<server.has_flag[totem_event_started]>:
            - narrate "<&7>Tidak ada Event Totem yang berjalan."
            - stop
        - flag server "totem_event_reason:dihentikan admin"
        - run totem_event_finish
        - stop
    - define chance <[sub]>
    - if !<[chance].is_decimal>:
        - narrate "<&c>Pakai: /totemevent chance waktu [batas] | stop | status"
        - stop
    - if <[chance]> <= 0 || <[chance]> > 100:
        - narrate "<&c>Chance harus lebih dari 0 dan paling besar 100 (persen)."
        - stop
    - define dur_text <context.args.get[2]||null>
    - if <[dur_text]> == null || <[dur_text].contains_text[-]>:
        - narrate "<&c>Waktu wajib diisi, contoh: 30m, 1h, 1d, 2w (tanpa rentang)."
        - stop
    - define dur <duration[<[dur_text]>]||null>
    - if <[dur]> == null:
        - narrate "<&c>Waktu tidak valid. Satuan: t s m h d w y (contoh 1d)."
        - stop
    - if <[dur].in_seconds> <= 0:
        - narrate "<&c>Waktu harus lebih dari 0."
        - stop
    - define limit <context.args.get[3]||0>
    - if !<[limit].is_integer> || <[limit]> < 0:
        - narrate "<&c>Batas totem harus angka bulat 0 atau lebih (0 = tanpa batas)."
        - stop
    - if <server.has_flag[totem_event_started]>:
        - if <server.has_flag[totem_event]>:
            - narrate "<&c>Event Totem masih berjalan. Pakai /totemevent stop dulu."
            - stop
        - run totem_event_finish
    - flag server totem_event:<[chance]> expire:<[dur]>
    - flag server totem_event_started
    - flag server totem_event_count:0
    - if <[limit]> > 0:
        - flag server totem_event_limit:<[limit]>
    - else:
        - flag server totem_event_limit:!
    - run totem_event_watch
    - define until <util.time_now.add[<[dur]>].to_zone[Asia/Jakarta].format[d/MM HH:mm]>
    - announce "<&6>[Berkah Dewa] <&e>Event Totem dimulai! Evoker menjatuhkan totem dengan peluang <[chance]>% selama <[dur].formatted> (sampai <[until]> WIB)."
    - announce to_console "[TOTEMEVENT] <player.name||console> chance=<[chance]> durasi=<[dur].formatted> batas=<[limit]>"


# =============================================================================
#  5. MENDING
# =============================================================================
mendingvillager_listener:
    type: world
    debug: false
    events:
        on player right clicks villager:
        - run mending_villager_clean def:<context.entity>
        after villager acquires trade:
        - define result <context.trade.result>
        - if <[result].material.name> != enchanted_book || !<[result].enchantment_map.contains[mending]>:
            - stop
        - define villager <context.entity>
        - inject mending_villager_roll
        after player trades with merchant:
        - define result <context.trade.result>
        - if <[result].material.name> != enchanted_book || !<[result].enchantment_map.contains[mending]>:
            - stop
        - flag <context.merchant> mending_sold
        - inventory close
        - run mending_villager_clean def:<context.merchant>
        - narrate "<&7>Stock Mendingku sudah habis, kamu bisa mencari itu ke villager lain."

# PERGESERAN PELUANG: ditambah event_mending_shift dari BKHC_Event.dsc (mending_boost/mending_nerf).
mending_villager_roll:
    type: task
    debug: false
    script:
    - define chance <script[config_brutal_legend].data_key[mending villager chance].add[<proc[event_mending_shift].context[none]>]>
    - if <[chance]> < 0:
        - define chance 0
    - if <[chance]> > 100:
        - define chance 100
    - flag <[villager]> mending_ok:!
    - flag <[villager]> mending_no:!
    - if <util.random.int[1].to[100]> <= <[chance]>:
        - flag <[villager]> mending_ok
    - else:
        - flag <[villager]> mending_no

mending_villager_clean:
    type: task
    debug: false
    definitions: villager
    script:
    - define has_mending false
    - foreach <[villager].trades> as:t:
        - define r <[t].result>
        - if <[r].material.name> == enchanted_book && <[r].enchantment_map.contains[mending]>:
            - define has_mending true
    - if <[has_mending]> && !<[villager].has_flag[mending_ok]> && !<[villager].has_flag[mending_no]>:
        - inject mending_villager_roll
    - define blocked <[villager].has_flag[mending_sold]>
    - if <[villager].has_flag[mending_no]>:
        - define blocked true
    - define keep <list>
    - define found false
    - define changed false
    - foreach <[villager].trades> as:trade:
        - define result <[trade].result>
        - if <[result].material.name> == enchanted_book && <[result].enchantment_map.contains[mending]>:
            - if <[blocked]> || <[found]>:
                - define changed true
            - else:
                - define found true
                - define keep:->:<[trade].with[max_uses=1]>
        - else:
            - define keep:->:<[trade]>
    - if <[changed]> || <[found]>:
        - adjust <[villager]> trades:<[keep]>

# PERGESERAN PELUANG: peluang gagal (ganti pufferfish) dikurangi oleh event_mending_shift.
fishing_mending_listener:
    type: world
    debug: false
    events:
        on player fishes while caught_fish:
        - if <context.item.enchantment_map.contains[mending]>:
            - define chance <script[config_brutal_legend].data_key[mending fishing chance].sub[<proc[event_mending_shift].context[<player>]>]>
            - if <[chance]> < 0:
                - define chance 0
            - if <[chance]> > 100:
                - define chance 100
            - if <util.random.int[1].to[100]> <= <[chance]>:
                - determine caught:pufferfish


# =============================================================================
#  6. NAMETAG DAN CHAT
# =============================================================================
hide_nametag_listener:
    type: world
    debug: false
    events:
        after player joins:
        - team name:hidden_nametag option:name_tag_visibility status:never add:<player>

local_chat_listener:
    type: world
    debug: false
    events:
        on player chats:
        - define radius <script[config_brutal_legend].data_key[chat radius]>
        - define hearers <player.location.find_players_within[<[radius]>].include[<player>].deduplicate>
        - if <[hearers].size> <= 1:
            - narrate "<&7>Tidak ada seorangpun dalam radius <[radius]> blok yang mendengarmu."
            - announce to_console "[CC] <player.name>: <context.message>"
            - determine cancelled
        - else:
            - narrate "<&7><context.message>" targets:<[hearers]>
            - announce to_console "[CHAT] <player.name>: <context.message>"
            - determine cancelled


# =============================================================================
#  7. GAMEPLAY
# =============================================================================
gameplay_handler:
    type: world
    debug: false
    events:
        on player breaks ancient_debris:
        - narrate "<&4>Disable"
        - determine cancelled
        on player quits bukkit_priority:HIGHEST:
        - determine none
        on player joins bukkit_priority:HIGHEST:
        - determine none


# =============================================================================
#  8. PENGGELEDAHAN INVENTORY (kompatibel Bedrock)
# =============================================================================
frisk_start_task:
    type: task
    debug: false
    definitions: target
    script:
    - define cfg <script[config_brutal_legend]>
    - define prefix <[cfg].parsed_key[message.prefix]>
    - if !<[target].is_player||false>:
        - stop
    - if <[target].name> == <player.name>:
        - stop
    - if <[target].has_flag[frisk_by]>:
        - narrate "<[prefix]> <&f>Pemain itu masih memilih permintaan lain."
        - stop
    - flag <[target]> frisk_by:<player> expire:30s
    - narrate "<[prefix]> <[cfg].parsed_key[message.req inventory]>"
    - narrate "<[prefix]> <&e><player.name> <[cfg].parsed_key[message.get req inventory.1]>" targets:<[target]>
    - narrate "<[prefix]> <&7>Menu tidak muncul? Ketik <&a>/izinkangeledah<&7> atau <&c>/tolakgeledah<&7>." targets:<[target]>
    - inventory open d:frisk_request_gui player:<[target]>

inventory_check:
    type: world
    debug: false
    events:
        on player right clicks player:
        - ratelimit <player> 1t
        - if !<player.is_sneaking> || <player.item_in_hand> !matches air:
            - stop
        - run frisk_start_task def:<context.entity>

geledah_command:
    type: command
    name: geledah
    debug: false
    description: Meminta izin menggeledah inventory pemain lain.
    usage: /geledah pemain
    script:
    - if !<player.is_player||false>:
        - stop
    - define target <server.match_player[<context.args.get[1]||>]||null>
    - if <[target]> == null:
        - narrate "<&c>Pemain tidak ditemukan. Pakai: /geledah pemain"
        - stop
    - if <player.world> != <[target].world>:
        - narrate "<&c>Kamu harus berada dekat pemain itu."
        - stop
    - if <player.location.distance[<[target].location>]> > 4:
        - narrate "<&c>Kamu harus berada dalam jarak 4 blok dari pemain itu."
        - stop
    - run frisk_start_task def:<[target]>

frisk_yes_button:
    type: item
    material: lime_wool
    display name: <&a><&l>IZINKAN
    lore:
    - <&7>Izinkan inventory-mu digeledah.

frisk_no_button:
    type: item
    material: red_wool
    display name: <&c><&l>TOLAK
    lore:
    - <&7>Tolak penggeledahan.

frisk_info_item:
    type: item
    material: paper
    display name: <&e><&l>Permintaan Penggeledahan
    lore:
    - <&7>Seorang pemain meminta izin untuk
    - <&7>melihat dan mengambil isi inventory-mu.
    - <&7>Namanya ada di chat.

frisk_request_gui:
    type: inventory
    inventory: chest
    title: <&0>Izin Penggeledahan
    gui: true
    slots:
    - [] [] [] [] [] [] [] [] []
    - [] [] [frisk_yes_button] [] [frisk_info_item] [] [frisk_no_button] [] []
    - [] [] [] [] [] [] [] [] []

frisk_gui_handler:
    type: world
    debug: false
    events:
        on player clicks frisk_yes_button in frisk_request_gui:
        - inventory close
        - run frisk_accept_task
        on player clicks frisk_no_button in frisk_request_gui:
        - inventory close
        - run frisk_reject_task

frisk_accept_task:
    type: task
    debug: false
    script:
    - define requester <player.flag[frisk_by]||null>
    - flag <player> frisk_by:!
    - if <[requester]> == null:
        - narrate "<&7>Tidak ada permintaan penggeledahan, atau sudah kedaluwarsa."
        - stop
    - if !<[requester].is_online>:
        - narrate "<&7>Pemain itu sudah tidak online."
        - stop
    - inventory open d:<player.inventory> player:<[requester]>
    - flag <[requester]> frisking:<player> expire:10m
    - narrate "<&7>Kamu mengizinkan <[requester].name> menggeledahmu."
    - narrate "<&7><player.name> mengizinkan penggeledahan." targets:<[requester]>

frisk_reject_task:
    type: task
    debug: false
    script:
    - define requester <player.flag[frisk_by]||null>
    - flag <player> frisk_by:!
    - if <[requester]> == null:
        - narrate "<&7>Tidak ada permintaan penggeledahan, atau sudah kedaluwarsa."
        - stop
    - narrate "<&7>Kamu menolak penggeledahan."
    - if <[requester].is_online>:
        - define cfg <script[config_brutal_legend]>
        - narrate "<[cfg].parsed_key[message.prefix]> <[cfg].parsed_key[message.reject req inventory]>" targets:<[requester]>

frisk_izinkan_command:
    type: command
    name: izinkangeledah
    debug: false
    description: Mengizinkan penggeledahan inventory-mu.
    usage: /izinkangeledah
    script:
    - if !<player.is_player||false>:
        - stop
    - run frisk_accept_task

frisk_tolak_command:
    type: command
    name: tolakgeledah
    debug: false
    description: Menolak penggeledahan inventory-mu.
    usage: /tolakgeledah
    script:
    - if !<player.is_player||false>:
        - stop
    - run frisk_reject_task

frisk_done_listener:
    type: world
    debug: false
    events:
        after player closes inventory:
        - if !<player.has_flag[frisking]>:
            - stop
        - define target <player.flag[frisking]>
        - flag <player> frisking:!
        - define prefix <script[config_brutal_legend].parsed_key[message.prefix]>
        - narrate "<[prefix]> <&f>Kamu selesai menggeledah <&e><[target].name><&f>."
        - if <[target].is_online>:
            - narrate "<[prefix]> <&e><player.name> <&f>selesai menggeledah inventory-mu." targets:<[target]>
            - title "title:<&e>Penggeledahan selesai" "subtitle:<&7>oleh <player.name>" targets:<[target]>
        on player quits:
        - flag <player> frisking:!


# =============================================================================
#  9. ITEM (golden apple, cooldown, mace, anti-explode)
# =============================================================================
golden_apple_limit_task:
    type: task
    debug: false
    script:
    - define max <script[config_brutal_legend].data_key[max stack golden apple]>
    - foreach <player.inventory.find_all_items[golden_apple]> as:slot:
        - define qty <player.inventory.slot[<[slot]>].quantity>
        - inventory adjust slot:<[slot]> max_stack_size:<[max]>
        - if <[qty]> > <[max]>:
            - inventory adjust slot:<[slot]> quantity:<[max]>
            - give <item[golden_apple].with[max_stack_size=<[max]>]> quantity:<[qty].sub[<[max]>]>

stack_golden_apple:
    type: world
    debug: false
    events:
        after player joins:
        - run golden_apple_limit_task
        after player picks up golden_apple:
        - run golden_apple_limit_task
        after player clicks golden_apple in inventory:
        - run golden_apple_limit_task
        after player crafts golden_apple:
        - run golden_apple_limit_task

item_cooldown:
    type: world
    debug: false
    events:
        on player damages player:
        - define cooldown <script[config_brutal_legend].data_key[trident cooldown]>
        - if <player.inventory.contains_item[trident]>:
            - itemcooldown trident d:<[cooldown]>
        - if <context.entity.inventory.contains_item[trident]>:
            - itemcooldown trident d:<[cooldown]> player:<context.entity>
        after ender_pearl launched:
        - if <context.entity.shooter.is_player.if_null[false]>:
            - define thrower <context.entity.shooter>
            - wait 3t
            - itemcooldown ender_pearl d:<script[config_brutal_legend].data_key[ender pearl cooldown]> player:<[thrower]>

mace_cooldown:
    type: world
    debug: false
    events:
        on player damages entity with:mace:
        - if <player.has_flag[mace_cd]>:
            - determine cancelled
            - ratelimit <player> 1s
            - narrate "<&c>Mace masih cooldown <player.flag_expiration[mace_cd].from_now.formatted>."
            - stop
        - flag <player> mace_cd expire:5s
        - itemcooldown mace d:5s

disable_explode:
    type: world
    debug: false
    events:
        on player crafts respawn_anchor:
        - narrate "<&4>Disable"
        - determine cancelled
        on player crafts end_crystal:
        - narrate "<&4>Disable"
        - determine cancelled
        on player right clicks block with:respawn_anchor:
        - narrate "<&4>Disable"
        - determine cancelled
        on player right clicks block with:end_crystal:
        - narrate "<&4>Disable"
        - determine cancelled
        on player right clicks respawn_anchor with:glowstone:
        - narrate "<&4>Disable"
        - determine cancelled


# =============================================================================
#  10. KOMPAS DAN TAB LIST
# =============================================================================
compass_handler:
    type: world
    debug: false
    events:
        on player right clicks block with:compass:
        - compass <script[config_brutal_legend].data_key[compass target]>

#tab_listener:
#   type: world
#    debug: false
#    events:
#        on reload scripts:
#        - flag server HUD:!
#        - wait 2s
#        - run tab_loop
#        after player joins:
#        - if !<server.has_flag[HUD]>:
#            - run tab_loop
#
#tab_loop:
#    type: task
#    debug: false
#    script:
#    - flag server HUD:<queue.id>
#    - while <server.has_flag[HUD]> && <server.online_players.size.is[more].than[0]>:
#        - foreach <server.online_players> as:viewer:
#           - adjust <[viewer]> tab_list_info:<proc[tab_header]>|<proc[tab_footer].context[<[viewer]>]>
#       - wait 10t
#    - flag server HUD:!
#
#tab_header:
#    type: procedure
#    debug: false
#    script:
#    - define x:->:<&4><&l>BACODKAU
#    - define x:->:<&4><&l>HARDCORE
#    - define x:->:<&r>
#    - determine <[x].separated_by[<n>]>
#
#tab_footer:
#    type: procedure
#    debug: false
#    definitions: player
#    script:
#    - define x:->:<&r>
#    - define "x:->:<&c>PING<&7><&l>: <&7><[player].ping> • <&c>TPS<&7>: <&7><server.recent_tps.get[1].as_money>"
#    - define hidden <server.online_players.filter_tag[<[filter_value].is_vanished||false>]>
#    - define "x:->:<&c>Online Players<&7><&l>: <&7><server.online_players.size.sub[<[hidden].size>]>"
#    - define "x:->:<&c>Time<&7><&l>: <&7><util.time_now.to_zone[Asia/Jakarta].format[HH:mm]> WIB - <util.time_now.to_zone[Asia/Jakarta].format[d/MM/yyyy]>"
#    - define x:->:<&r>
#    - determine <[x].separated_by[<n>]>

# =============================================================================
#  BACODKAU HARDCORE (BKHC) - FILE 2: SISTEM EVENT (30 global/both + 25 personal)
#  Letakkan di: plugins/Denizen/scripts/BKHC_Event.dsc
#  Butuh: BKHC_Core.dsc (config_brutal_legend)
#
#  Perintah: /eventlist (alias /event), /eventadmin ... (permission brutal.event.admin)
#  Item: global_booster_item, personal_booster_item, lootbox_item
#
#  Isi:
#    1.  event_loop_starter, event_master_loop         loop utama
#        event_global_start/finish, event_personal_assign/finish
#        event_pick, event_active, event_mending_shift  procedure
#        event_on_start, event_on_end                   hook mekanik khusus
#    2.  event_player_tick, event_bars                  efek per detik + bossbar
#    3.  event_config (30 event global/both), event_global_config (angka globalnya)
#        pe_config (angka 25 event personal)
#    4.  all_events ditaruh DI DALAM event_config (lihat bagian 3)
#    5.  eventlist_command, event_list_gui, event_gui_open, eventadmin_command
#    6.  global_booster_item, personal_booster_item, lootbox_item,
#        booster_handler, pe_item_lock
#    7.  event_gameplay_listeners   mekanik 30 event global/both
#    8.  pe_listeners               mekanik 25 event personal
# =============================================================================


# =============================================================================
#  1. MESIN: LOOP, PENJADWAL, GLOBAL & PERSONAL
# =============================================================================
event_loop_starter:
    type: world
    debug: false
    events:
        on server start:
        - flag server event_loop_alive:!
        - flag server event_loop_gen:<util.current_time_millis>
        - run event_master_loop
        on reload scripts:
        - flag server event_loop_alive:!
        - flag server event_loop_gen:<util.current_time_millis>
        - run event_master_loop
        after player joins:
        - run event_master_loop
        on player quits:
        - if <player.has_flag[evbar_g]>:
            - bossbar remove evg_<player.uuid> players:<player>
        - if <player.has_flag[evbar_p]>:
            - bossbar remove evp_<player.uuid> players:<player>
        - flag <player> evbar_g:!
        - flag <player> evbar_p:!

event_master_loop:
    type: task
    debug: false
    script:
    - if <server.has_flag[event_loop_alive]>:
        - stop
    - define gen <server.flag[event_loop_gen]||0>
    - define tick 0
    - while <server.flag[event_loop_gen]||0> == <[gen]>:
        - flag server event_loop_alive expire:6s
        - define tick:++
        - if <server.has_flag[global_event_started]>:
            - if !<server.has_flag[active_global_event]>:
                - run event_global_finish
        - else if !<server.has_flag[global_event_cooldown]> && <server.online_players.size> > 0:
            - run event_global_start
        - define g <server.flag[active_global_event]||none>
        - if <[g]> == eternal_night && <[tick].mod[10]> == 0:
            - execute as_server "time set midnight"
        - foreach <server.online_players> as:p:
            - run event_player_tick def:<[p]>|<[g]>|<[tick]>
        - wait 1s

event_global_start:
    type: task
    debug: false
    script:
    - define cfg <script[event_config]>
    - define id <[forced]||none>
    - if <[id]> == none:
        - define id <proc[event_pick].context[global]>
    - if <[id]> == none:
        - stop
    - define dur <[cfg].data_key[all_events.<[id]>.duration]>
    - flag server global_event_started
    - flag server global_event_current_id:<[id]>
    - flag server active_global_event:<[id]> expire:<[dur]>
    - flag server active_global_event_total:<duration[<[dur]>].in_seconds>
    - flag server last_global_event:<[id]>
    - flag server global_event_cooldown:!
    - define name <[cfg].parsed_key[all_events.<[id]>.name]>
    - announce "<&6><&l>[EVENT GLOBAL] <&r><[name]> <&e>dimulai selama <duration[<[dur]>].formatted>!"
    - announce "<&7><[cfg].parsed_key[all_events.<[id]>.desc1]>"
    - announce to_console "[EVENT] global start <[id]> <[dur]>"
    - playsound <server.online_players> sound:entity.wither.spawn volume:0.6 pitch:1.2
    - run event_on_start def:<[id]>|global|null

event_global_finish:
    type: task
    debug: false
    script:
    - if !<server.has_flag[global_event_started]>:
        - stop
    - define reason <[reason]||natural>
    - define id <server.flag[global_event_current_id]||none>
    - define cfg <script[event_config]>
    - define cd <[cfg].data_key[cooldown_after_global]>
    - flag server global_event_started:!
    - flag server active_global_event:!
    - flag server active_global_event_total:!
    - flag server global_event_current_id:!
    - flag server global_event_cooldown expire:<[cd]>
    - flag server global_event_cooldown_total:<duration[<[cd]>].in_seconds>
    - if <[id]> != none:
        - define name <[cfg].parsed_key[all_events.<[id]>.name]>
        - announce "<&6><&l>[EVENT GLOBAL] <&r><[name]> <&e>telah berakhir. Server masuk masa tenang."
        - announce to_console "[EVENT] global end <[id]> (<[reason]>)"
        - playsound <server.online_players> sound:block.beacon.deactivate volume:0.6 pitch:1.0
        - run event_on_end def:<[id]>|<[reason]>|null

event_personal_assign:
    type: task
    debug: false
    script:
    - define cfg <script[event_config]>
    - define id <[forced]||none>
    - if <[id]> == none:
        - define id <proc[event_pick].context[personal]>
    - if <[id]> == none:
        - stop
    - define dur <[duration]||none>
    - if <[dur]> == none:
        - define dur <[cfg].data_key[personal_duration]>
        - if <[id].starts_with[pe_]>:
            - define dur <script[pe_config].data_key[<[id].after[pe_]>.duration]||<[dur]>>
    - define cd <[cfg].data_key[personal_cooldown]>
    - flag <[p]> active_personal_event:<[id]> expire:<[dur]>
    - flag <[p]> active_personal_event_total:<duration[<[dur]>].in_seconds>
    - flag <[p]> personal_event_cooldown expire:<duration[<[dur]>].add[<duration[<[cd]>]>]>
    - define name <[cfg].parsed_key[all_events.<[id]>.name]>
    - narrate "<&b><&l>[EVENT PERSONAL] <&r><[name]> <&b>aktif untukmu selama <duration[<[dur]>].formatted>." targets:<[p]>
    - narrate "<&7><[cfg].parsed_key[all_events.<[id]>.desc1]>" targets:<[p]>
    - flag <[p]> last_personal_event:<[id]>
    - flag <[p]> pe_was_active
    - playsound <[p]> sound:entity.ender_dragon.growl volume:1 pitch:1.6
    - run event_on_start def:<[id]>|personal|<[p]>

event_personal_finish:
    type: task
    debug: false
    definitions: p|reason
    script:
    - define id <[p].flag[active_personal_event]||<[p].flag[last_personal_event]||none>>
    - if <[id]> == none:
        - stop
    - flag <[p]> active_personal_event:!
    - flag <[p]> active_personal_event_total:!
    - flag <[p]> pe_was_active:!
    - define cfg <script[event_config]>
    - define cd <[cfg].data_key[personal_cooldown]>
    - flag <[p]> personal_event_cooldown expire:<[cd]>
    - define name <[cfg].parsed_key[all_events.<[id]>.name]>
    - narrate "<&b><&l>[EVENT PERSONAL] <&r><[name]> <&b>berakhir (<[reason]||selesai>)." targets:<[p]>
    - playsound <[p].location> sound:entity.player.levelup volume:1 pitch:1.4 targets:<[p]>
    - run event_on_end def:<[id]>|<[reason]||selesai>|<[p]>

event_pick_weight:
    type: procedure
    debug: false
    definitions: id
    script:
    - define cfg <script[event_config]>
    - define weight <[cfg].data_key[all_events.<[id]>.weight]||1>
    - if <[cfg].data_key[all_events.<[id]>.kind]> == positive:
        - define weight <[weight].div[4].round_up>
    - determine <[weight]>

event_chance:
    type: procedure
    debug: false
    definitions: scope|event
    script:
    - define cfg <script[event_config]>
    - define total_weight 0
    - define event_weight 0
    - define last <server.flag[last_global_event]||none>
    - foreach <[cfg].data_key[event_ids]> as:id:
        - define sc <[cfg].data_key[all_events.<[id]>.scope]||both>
        - if <[sc]> != both && <[sc]> != <[scope]>:
            - foreach next
        - if <[scope]> == global && <[id]> == <[last]>:
            - foreach next
        - if <[id]> == totem_of_life && <server.has_flag[totem_event_started]>:
            - foreach next
        - define weight <proc[event_pick_weight].context[<[id]>]>
        - define total_weight <[total_weight].add[<[weight]>]>
        - if <[id]> == <[event]>:
            - define event_weight <[weight]>
    - if <[event_weight]> == 0 || <[total_weight]> == 0:
        - determine 0
    - determine <[event_weight].div[<[total_weight]>].mul[100].round_to[2]>

event_rarity:
    type: procedure
    debug: false
    definitions: scope|event
    script:
    - define chance 0
    - if <[scope]> == both:
        - define global_chance <proc[event_chance].context[global|<[event]>]>
        - define personal_chance <proc[event_chance].context[personal|<[event]>]>
        - if <[global_chance]> > 0:
            - define chance <[global_chance]>
        - if <[personal_chance]> > 0:
            - if <[chance]> == 0:
                - define chance <[personal_chance]>
            - else if <[personal_chance]> < <[chance]>:
                - define chance <[personal_chance]>
    - else:
        - define chance <proc[event_chance].context[<[scope]>|<[event]>]>
    - if <[chance]> == 0:
        - determine "<&8>Unavailable"
    - else if <[chance]> <= 0.5:
        - determine "<&d><&l>Mythic"
    - else if <[chance]> <= 1.5:
        - determine "<&6><&l>Legendary"
    - else if <[chance]> <= 3:
        - determine "<&b><&l>Rare"
    - else if <[chance]> <= 5:
        - determine "<&a>Uncommon"
    - determine "<&7>Common"

event_pick:
    type: procedure
    debug: false
    definitions: scope
    script:
    - define cfg <script[event_config]>
    - define pool <list>
    - define last <server.flag[last_global_event]||none>
    - foreach <[cfg].data_key[event_ids]> as:id:
        - define sc <[cfg].data_key[all_events.<[id]>.scope]||both>
        - if <[sc]> != both && <[sc]> != <[scope]>:
            - foreach next
        - if <[scope]> == global && <[id]> == <[last]>:
            - foreach next
        - if <[id]> == totem_of_life && <server.has_flag[totem_event_started]>:
            - foreach next
        - repeat <proc[event_pick_weight].context[<[id]>]>:
            - define pool:->:<[id]>
    - if <[pool].is_empty>:
        - determine none
    - determine <[pool].random>

event_active:
    type: procedure
    debug: false
    definitions: id|who
    script:
    - if <server.flag[active_global_event]||none> == <[id]>:
        - determine true
    - if <[who].is_player||false>:
        - if <[who].flag[active_personal_event]||none> == <[id]>:
            - determine true
    - determine false

event_mending_shift:
    type: procedure
    debug: false
    definitions: who
    script:
    - define shift 0
    - if <proc[event_active].context[mending_boost|<[who]>]>:
        - define shift <[shift].add[10]>
    - if <proc[event_active].context[mending_nerf|<[who]>]>:
        - define shift <[shift].sub[15]>
    - determine <[shift]>

event_on_start:
    type: task
    debug: false
    definitions: id|scope|p
    script:
    - define gcfg <script[event_global_config]>
    - if <[id]> == plague_outbreak:
        - define pick <server.online_players.random||none>
        - if <[pick]> != none:
            - flag <[pick]> plague_sick expire:<[gcfg].data_key[plague_outbreak.sick_duration]>
            - narrate "<&2>Kamu terjangkit wabah! Jauhi pemain lain dan minum susu." targets:<[pick]>
    - if <[id]> == totem_of_life:
        - execute as_server "totemevent <[gcfg].data_key[totem_of_life.drop_chance]> <script[event_config].data_key[all_events.totem_of_life.duration]>"
    - if <[id]> == void_maintenance:
        - if <[scope]> == global:
            - foreach <server.online_players> as:target:
                - if <[target].has_flag[in_void]>:
                    - define left <[target].flag_expiration[in_void].from_now.in_seconds>
                    - if <[left]> > 60:
                        - flag <[target]> in_void expire:1m
                        - flag <[target]> void_total:60
                        - narrate "<&b>Void Maintenance memangkas waktu tunggumu menjadi maksimal 1 menit." targets:<[target]>
        - else if <[p].is_player||false> && <[p].has_flag[in_void]>:
            - define left <[p].flag_expiration[in_void].from_now.in_seconds>
            - if <[left]> > 60:
                - flag <[p]> in_void expire:1m
                - flag <[p]> void_total:60
                - narrate "<&b>Void Maintenance memangkas waktu tunggumu menjadi maksimal 1 menit." targets:<[p]>
    - if <[id]> == pe_glass_cannon:
        - flag <[p]> pe_glass_cannon_old_max_health:<[p].health_max>
        - adjust <[p]> max_health:<script[pe_config].data_key[glass_cannon.max_health]>
    - if <[id]> == pe_hot_potato:
        - give tnt to:<[p].inventory> slot:offhand
    - if <[id]> == pe_misfortune_punish:
        - define dur <script[pe_config].data_key[misfortune_punish.max_duration]>
        - foreach <list[speed|haste|strength|regeneration|resistance|jump_boost|fire_resistance|water_breathing|night_vision|invisibility|absorption|health_boost|saturation|luck|slow_falling|conduit_power|dolphins_grace|hero_of_the_village]> as:eff:
            - cast <[eff]> remove <[p]>
        - cast bad_omen <[p]> duration:<[dur]> amplifier:4
        - cast unluck <[p]> duration:<[dur]> amplifier:2

event_on_end:
    type: task
    debug: false
    definitions: id|reason|p
    script:
    - if <[id]> == plague_outbreak:
        - foreach <server.online_players> as:pl:
            - flag <[pl]> plague_sick:!
    - if <[id]> == totem_of_life && <[reason]> == admin && <server.has_flag[totem_event_started]>:
        - execute as_server "totemevent stop"
    - if <[id]> == pe_glass_cannon:
        - define old_max_health <[p].flag[pe_glass_cannon_old_max_health]||20.0>
        - adjust <[p]> max_health:<[old_max_health]>
        - flag <[p]> pe_glass_cannon_old_max_health:!
    - if <[id]> == pe_titan_will:
        - cast absorption remove <[p]>
        - flag <[p]> pe_titan_set:!
    - if <[id]> == pe_hot_potato:
        - if <[p].item_in_offhand.material.name> == tnt:
            - equip <[p]> offhand:air
            - explode power:4.0 <[p].location> breakblocks
    - if <[id].starts_with[pe_]>:
        - foreach <list[pe_guardian_used|pe_ct_midas|pe_ct_rtp|pe_ct_bloodthirst|pe_ct_shuffle|pe_ct_spider|pe_ct_fishing|pe_ct_crit|pe_ct_swap|pe_xp_level_start|pe_titan_set]> as:state:
            - flag <[p]> <[state]>:!

# =============================================================================
#  2. TICK PER PEMAIN (efek) DAN BOSSBAR
# =============================================================================
event_player_tick:
    type: task
    debug: false
    definitions: p|g|tick
    script:
    - if !<[p].is_online>:
        - stop
    - define in_void <[p].has_flag[in_void]>
    - if <[p].has_flag[active_personal_event]>:
        - flag <[p]> pe_was_active
    - else if <[p].has_flag[pe_was_active]>:
        - run event_personal_finish def:<[p]>|<element[waktu habis]>
    - else if !<[in_void]> && !<[p].has_flag[personal_event_cooldown]>:
        - if !<[p].has_flag[personal_init]>:
            - flag <[p]> personal_init
            - flag <[p]> personal_event_cooldown expire:10m
        - else:
            - run event_personal_assign def.p:<[p]>
    - define q <[p].flag[active_personal_event]||none>
    - run event_bars def:<[p]>|<[g]>|<[q]>
    - if <[in_void]>:
        - stop
    - define act <list[<[g]>|<[q]>]>
    - define gcfg <script[event_global_config]>
    - define pecfg <script[pe_config]>
    - define in_main false
    - if <[p].world.name> == <script[config_brutal_legend].data_key[rtp world name]>:
        - define in_main true
    # --- event global/both ---
    - if <[act].contains[acid_water]>:
        - if <[p].location.material.name> == water:
            - cast poison <[p]> duration:<[gcfg].data_key[acid_water.poison_duration]> amplifier:<[gcfg].data_key[acid_water.poison_amplifier]>
            - cast nausea <[p]> duration:<[gcfg].data_key[acid_water.nausea_duration]> amplifier:<[gcfg].data_key[acid_water.nausea_amplifier]>
    - if <[act].contains[pollution]> && <[in_main]>:
        - if !<[p].inventory.slot[40].material.name.contains_text[<[gcfg].data_key[pollution.safe_helmet_contains]>]>:
            - cast poison <[p]> duration:<[gcfg].data_key[pollution.poison_duration]> amplifier:<[gcfg].data_key[pollution.poison_amplifier]>
    - if <[act].contains[freezing_cold]> && <[in_main]>:
        - if <[p].location.find_blocks[campfire|soul_campfire|fire|soul_fire|lava|magma_block|furnace|blast_furnace|smoker].within[<[gcfg].data_key[freezing_cold.heat_radius]>].is_empty>:
            - cast slowness <[p]> duration:4s amplifier:0
    - if <[act].contains[starvation_curse]>:
        - cast hunger <[p]> duration:4s amplifier:<[gcfg].data_key[starvation_curse.hunger_amplifier]>
    - if <[act].contains[lucky_person]>:
        - cast luck <[p]> duration:4s amplifier:<[gcfg].data_key[lucky_person.luck_amplifier]>
    - if <[act].contains[divine_wrath]>:
        - cast unluck <[p]> duration:4s amplifier:<[gcfg].data_key[divine_wrath.unluck_amplifier]>
    - if <[act].contains[world_faster]>:
        - cast speed <[p]> duration:4s amplifier:<[gcfg].data_key[world_faster.speed_amplifier]>
        - cast haste <[p]> duration:4s amplifier:<[gcfg].data_key[world_faster.haste_amplifier]>
    - if <[act].contains[slowest_world]>:
        - cast slowness <[p]> duration:4s amplifier:<[gcfg].data_key[slowest_world.slowness_amplifier]>
        - cast mining_fatigue <[p]> duration:4s amplifier:<[gcfg].data_key[slowest_world.mining_fatigue_amplifier]>
    - if <[act].contains[world_slowness]>:
        - cast slowness <[p]> duration:4s amplifier:<[gcfg].data_key[world_slowness.slowness_amplifier]>
    - if <[act].contains[plague_outbreak]> && <[p].has_flag[plague_sick]>:
        - define radius <[gcfg].data_key[plague_outbreak.infect_radius]>
        - define chance <[gcfg].data_key[plague_outbreak.infect_chance]>
        - define sick <[gcfg].data_key[plague_outbreak.sick_duration]>
        - cast weakness <[p]> duration:5s amplifier:<[gcfg].data_key[plague_outbreak.weakness_amplifier]>
        - if <[tick].mod[<[gcfg].data_key[plague_outbreak.nausea_every_ticks]>]> == 0:
            - cast nausea <[p]> duration:5s amplifier:0
        - foreach <[p].location.find_players_within[<[radius]>].exclude[<[p]>]> as:o:
            - if !<[o].has_flag[plague_sick]> && !<[o].has_flag[in_void]> && <util.random.int[1].to[100]> <= <[chance]>:
                - flag <[o]> plague_sick expire:<[sick]>
                - narrate "<&2>Kamu tertular wabah! Minum susu untuk sembuh." targets:<[o]>
    # --- event personal ---
    - if <[act].contains[pe_silent_stealth]>:
        - cast invisibility <[p]> duration:4s amplifier:0
    - if <[act].contains[pe_ghost_phasing]>:
        - adjust <[p]> fall_distance:0
    - if <[act].contains[pe_titan_will]>:
        - if !<[p].has_flag[pe_titan_set]>:
            - flag <[p]> pe_titan_set
            - cast absorption <[p]> duration:99999s amplifier:<[pecfg].data_key[titan_will.absorption_amplifier]>
        - if <[p].absorption_health||0> <= 0:
            - flag <[p]> pe_titan_set:!
            - run event_personal_finish def:<[p]>|<element[hati kuning habis]>
    - if <[act].contains[pe_overclock_worker]>:
        - cast haste <[p]> duration:4s amplifier:2
    - if <[act].contains[pe_heavy_anchor]>:
        - cast jump_boost <[p]> duration:4s amplifier:128
        - if <[p].location.material.name> == water:
            - adjust <[p]> velocity:<[p].velocity.with_y[-0.3]>
    - if <[act].contains[pe_blood_scent]> && <[tick].mod[5]> == 0:
        - foreach <[p].location.find_entities[living].within[<[pecfg].data_key[blood_scent.radius]>]> as:m:
            - if <[m].is_monster||false>:
                - adjust <[m]> target:<[p]>
    - if <[act].contains[pe_paranoia_stalker]> && <util.random.int[1].to[100]> <= <[pecfg].data_key[paranoia_stalker.trigger_chance]>:
        - playsound <[p]> sound:<list[entity.warden.ambient|ambient.cave|entity.lightning_bolt.thunder].random> volume:0.8 pitch:1
        - if <util.random.int[1].to[100]> <= <[pecfg].data_key[paranoia_stalker.blindness_chance]>:
            - cast blindness <[p]> duration:1s amplifier:0
    - if <[act].contains[pe_gravity_anomaly]>:
        - cast jump_boost <[p]> duration:4s amplifier:5
        - cast slow_falling <[p]> duration:4s amplifier:0
        - cast slowness <[p]> duration:4s amplifier:1
    - if <[act].contains[pe_cursed_magnet]>:
        - foreach <[p].location.find_entities[dropped_item|experience_orb].within[<[pecfg].data_key[cursed_magnet.radius]>]> as:e:
            - teleport <[e]> <[e].location.add[<[p].location.sub[<[e].location>].normalize.mul[2]>]>
    - if <[act].contains[pe_dimensional_glitch]> && <[tick].mod[5]> == 0:
        - time player <util.random.int[0].to[24000]>t reset:10s player:<[p]>
        - weather player <list[sunny|storm].random> reset:10s player:<[p]>
    - if <[act].contains[pe_shapeshifter_curse]> && <[tick].mod[30]> == 0:
        - cast speed <[p]> duration:30s amplifier:<util.random.int[0].to[2]>
        - playeffect effect:cloud at:<[p].location> quantity:20 offset:0.5,0.5,0.5
    - if <[act].contains[pe_arachnophobia]> && <[tick].mod[<[pecfg].data_key[arachnophobia.check_every_seconds]>]> == 0:
        - define below <[p].location.below.material.name>
        - if <[below]> == grass_block || <[below]> == dirt:
            - if <util.random.int[1].to[100]> <= <[pecfg].data_key[arachnophobia.spawn_chance]>:
                - spawn cave_spider <[p].location> save:cs
                - flag <entry[cs].spawned_entities.first> pe_arachno_target:<[p].uuid>
    - if <[act].contains[pe_misfortune_punish]> && <[tick].mod[5]> == 0:
        - if !<[p].location.find_blocks[bell].within[<[pecfg].data_key[misfortune_punish.village_radius]>].is_empty>:
            - run event_personal_finish def:<[p]>|<element[masuk desa]>

event_bars:
    type: task
    debug: false
    definitions: p|g|q
    script:
    - define cfg <script[event_config]>
    - define gid evg_<[p].uuid>
    - define pid evp_<[p].uuid>
    - if <[g]> != none:
        - define name <[cfg].parsed_key[all_events.<[g]>.name]>
        - define left <server.flag_expiration[active_global_event].from_now>
        - define total <server.flag[active_global_event_total]||600>
        - define prog <[left].in_seconds.div[<[total]>]>
        - if <[prog]> > 1:
            - define prog 1
        - define color <[cfg].data_key[all_events.<[g]>.bar]||green>
        - define emoji_index <[cfg].data_key[event_ids].find[<[g]>]>
        - define emoji <[cfg].data_key[event_emojis].get[<[emoji_index]>]||✨>
        - bossbar <[gid]> players:<[p]> "title:<[emoji]> <&6><&l>Global <&8>- <&r><[name]> <&8>- <&f><[left].formatted>" progress:<[prog]> color:<[color]>
        - flag <[p]> evbar_g
    - else if <server.has_flag[global_event_cooldown]>:
        - define left <server.flag_expiration[global_event_cooldown].from_now>
        - define total <server.flag[global_event_cooldown_total]||3600>
        - define prog <[left].in_seconds.div[<[total]>]>
        - if <[prog]> > 1:
            - define prog 1
        - bossbar <[gid]> players:<[p]> "title:⌛ <&e><&l>Global Event <&8>- <&f><[left].formatted>" progress:<[prog]> color:yellow
        - flag <[p]> evbar_g
    - else if <[p].has_flag[evbar_g]>:
        - bossbar remove <[gid]> players:<[p]>
        - flag <[p]> evbar_g:!
    - if <[q]> != none:
        - define name <[cfg].parsed_key[all_events.<[q]>.name]>
        - define left <[p].flag_expiration[active_personal_event].from_now>
        - define total <[p].flag[active_personal_event_total]||900>
        - define prog <[left].in_seconds.div[<[total]>]>
        - if <[prog]> > 1:
            - define prog 1
        - define color <[cfg].data_key[all_events.<[q]>.bar]||blue>
        - define emoji_index <[cfg].data_key[event_ids].find[<[q]>]>
        - define emoji <[cfg].data_key[event_emojis].get[<[emoji_index]>]||✨>
        - bossbar <[pid]> players:<[p]> "title:<[emoji]> <&b><&l>Personal <&8>- <&r><[name]> <&8>- <&f><[left].formatted>" progress:<[prog]> color:<[color]>
        - flag <[p]> evbar_p
    - else if <[p].has_flag[evbar_p]>:
        - bossbar remove <[pid]> players:<[p]>
        - flag <[p]> evbar_p:!


# =============================================================================
#  3. CONFIG: event_config (30 global/both) + event_global_config (angkanya)
#     + pe_config (angka 25 event personal)
# =============================================================================
event_config:
    type: data
    cooldown_after_global: 1h
    personal_duration: 25m
    personal_cooldown: 3h
    lootbox_chance: 2
    lootbox_rewards:
    - iron_ingot:4:12
    - iron_ingot:4:12
    - gold_ingot:2:6
    - redstone:8:24
    - lapis_lazuli:8:20
    - emerald:2:5
    - experience_bottle:4:10
    - cooked_beef:8:16
    - golden_carrot:6:12
    - arrow:16:32
    - coal:8:24
    - string:8:24
    - copper_ingot:4:16
    - amethyst_shard:4:12
    - quartz:4:12
    - glowstone_dust:4:12
    - firework_rocket:4:12
    - honey_bottle:1:3
    - phantom_membrane:1:3
    - golden_apple:1:2
    - shield:1:1
    - iron_pickaxe:1:1
    - ender_pearl:1:2
    - diamond:1:1

    event_ids:
    - double_drop
    - damage_bonus
    - acid_water
    - pollution
    - world_faster
    - creeper_birthday
    - gear_up
    - fortune_goddess
    - blast_furnace_danger
    - slowest_world
    - totem_of_life
    - no_exp
    - lucky_person
    - no_item_drop
    - void_maintenance
    - eternal_night
    - villager_strike
    - watch_out_bombs
    - tax_system
    - mending_boost
    - mending_nerf
    - lootbox_event
    - freezing_cold
    - starvation_curse
    - divine_wrath
    - reflected_damage
    - plague_outbreak
    - world_slowness
    - ghost_town
    - fragile_gear
    - pe_midas_touch
    - pe_guardian_angel
    - pe_blood_thirst
    - pe_silent_stealth
    - pe_ghost_phasing
    - pe_titan_will
    - pe_celestial_fishing
    - pe_lightning_striker
    - pe_overclock_worker
    - pe_soul_resonance
    - pe_kamikaze_corpse
    - pe_leaky_inventory
    - pe_paranoia_stalker
    - pe_glass_cannon
    - pe_heavy_anchor
    - pe_hunger_curse
    - pe_fragile_equipment
    - pe_blood_scent
    - pe_arachnophobia
    - pe_misfortune_punish
    - pe_gravity_anomaly
    - pe_cursed_magnet
    - pe_random_teleport
    - pe_explosive_sneeze
    - pe_swapper_punch
    - pe_inventory_shuffle
    - pe_dimensional_glitch
    - pe_hot_potato
    - pe_shapeshifter_curse
    - pe_chorus_diet

    event_emojis:
    - 🎁
    - ⚔️
    - 🌊
    - ☣️
    - 🏃
    - 🧟
    - 🛡️
    - 🍀
    - 🏭
    - 🐌
    - 🪬
    - 📉
    - 🐇
    - 💀
    - 🌀
    - 🌙
    - 🧑‍🌾
    - 💣
    - 🪙
    - 📖
    - 📕
    - 📦
    - 🥶
    - 🍖
    - 🙏
    - 🪞
    - 🦠
    - ⚓
    - 👻
    - 🧰
    - ⛏️
    - 🪽
    - 🩸
    - 🥷
    - 🫥
    - 🗿
    - 🎣
    - ⚡
    - ⏩
    - 🔔
    - 🧨
    - 🕳️
    - 👁️
    - 🥃
    - ⛓️
    - 🥄
    - 🪓
    - 🐺
    - 🕷️
    - 🎭
    - 🌌
    - 🧲
    - 🪄
    - 💨
    - 🥊
    - 🔀
    - 🪐
    - 🥔
    - 🦎
    - 🍇

    all_events:
        double_drop:
            name: "<&a><&l>Double Drop"
            scope: both
            kind: positive
            weight: 10
            duration: 15m
            bar: green
            icon: diamond
            desc1: "<&7>Drop mob yang dibunuh pemain jadi 2x lipat."
            desc2: "<&7>Tidak berlaku untuk Evoker dan spawner."
        damage_bonus:
            name: "<&c><&l>Damage Bonus"
            scope: both
            kind: positive
            weight: 10
            duration: 15m
            bar: red
            icon: iron_sword
            desc1: "<&7>Semua serangan pemain +50% damage."
            desc2: ""
        acid_water:
            name: "<&4><&l>Air Kotor"
            scope: both
            kind: negative
            weight: 4
            duration: 35m
            bar: purple
            icon: potion
            desc1: "<&7>Berada di dalam air memberi Poison dan Nausea."
            desc2: ""
        pollution:
            name: "<&8><&l>Polusi Udara"
            scope: both
            kind: negative
            weight: 4
            duration: 30m
            bar: white
            icon: glass
            desc1: "<&7>Tanpa kaca di kepala kamu terkena Poison."
            desc2: "<&7>Berlaku di dunia utama saja."
        world_faster:
            name: "<&e><&l>World Faster"
            scope: both
            kind: positive
            weight: 8
            duration: 5m
            bar: yellow
            icon: sugar
            desc1: "<&7>Speed II dan Haste II untuk pemain."
            desc2: ""
        creeper_birthday:
            name: "<&e><&l>Creeper Birthday"
            scope: global
            kind: negative
            weight: 4
            duration: 25m
            bar: yellow
            icon: creeper_head
            desc1: "<&7>Creeper yang muncul membawa efek ramuan acak."
            desc2: ""
        gear_up:
            name: "<&c><&l>GEAR UP"
            scope: global
            kind: negative
            weight: 4
            duration: 30m
            bar: red
            icon: netherite_chestplate
            desc1: "<&7>Monster humanoid muncul memakai armor besi/diamond."
            desc2: ""
        fortune_goddess:
            name: "<&a><&l>Berkah Dewi Keberuntungan"
            scope: both
            kind: positive
            weight: 10
            duration: 15m
            bar: green
            icon: raw_gold
            desc1: "<&7>Ore yang ditambang menjatuhkan 2x lipat."
            desc2: ""
        blast_furnace_danger:
            name: "<&c><&l>Blaster Furnaces"
            scope: global
            kind: negative
            weight: 3
            duration: 30m
            bar: red
            icon: blast_furnace
            desc1: "<&7>Furnace berisiko meledak (3%) saat memasak."
            desc2: "<&7>Ledakan tidak merusak blok."
        slowest_world:
            name: "<&b><&l>Slowest World Records"
            scope: both
            kind: negative
            weight: 3
            duration: 25m
            bar: blue
            icon: soul_sand
            desc1: "<&7>Slowness II dan Mining Fatigue untuk pemain."
            desc2: ""
        totem_of_life:
            name: "<&6><&l>TOTEM OF LIFE"
            scope: global
            kind: positive
            weight: 6
            duration: 5m
            bar: pink
            icon: totem_of_undying
            desc1: "<&7>Evoker menjatuhkan Totem dengan peluang 2%."
            desc2: "<&7>Memakai sistem /totemevent."
        no_exp:
            name: "<&8><&l>Dimana EXP-ku?"
            scope: global
            kind: negative
            weight: 3
            duration: 40m
            bar: blue
            icon: experience_bottle
            desc1: "<&7>Orb EXP tidak muncul dari sumber apa pun."
            desc2: ""
        lucky_person:
            name: "<&a><&l>Orang Beruntung"
            scope: both
            kind: positive
            weight: 10
            duration: 15m
            bar: green
            icon: rabbit_foot
            desc1: "<&7>Efek Luck II untuk pemain."
            desc2: ""
        no_item_drop:
            name: "<&4><&l>Dimana Item-ku??"
            scope: both
            kind: negative
            weight: 2
            duration: 30m
            bar: red
            icon: skeleton_skull
            desc1: "<&7>Item hancur dan tidak drop saat pemain mati."
            desc2: ""
        void_maintenance:
            name: "<&b><&l>Void Maintenance"
            scope: both
            kind: positive
            weight: 8
            duration: 20m
            bar: blue
            icon: end_portal_frame
            desc1: "<&7>Hukuman di void dipangkas menjadi 1 menit."
            desc2: ""
        eternal_night:
            name: "<&1><&l>M-Malam??"
            scope: global
            kind: negative
            weight: 3
            duration: 25m
            bar: purple
            icon: clock
            desc1: "<&7>Dunia utama terkunci malam, tidak bisa tidur."
            desc2: ""
        villager_strike:
            name: "<&c><&l>Apakah Villager Marah?"
            scope: both
            kind: negative
            weight: 3
            duration: 30m
            bar: red
            icon: emerald
            desc1: "<&7>Villager menolak semua transaksi."
            desc2: ""
        watch_out_bombs:
            name: "<&4><&l>Awas Bom!"
            scope: both
            kind: negative
            weight: 3
            duration: 30m
            bar: red
            icon: tnt
            desc1: "<&7>Menambang stone/ore berisiko ledakan kecil (3%)."
            desc2: "<&7>Ledakan tidak merusak blok."
        tax_system:
            name: "<&e><&l>Pajak Negara"
            scope: both
            kind: negative
            weight: 4
            duration: 35m
            bar: yellow
            icon: gold_nugget
            desc1: "<&7>12% ore gagal drop saat ditambang."
            desc2: ""
        mending_boost:
            name: "<&a><&l>Sebuah Buku?"
            scope: both
            kind: positive
            weight: 6
            duration: 15m
            bar: green
            icon: enchanted_book
            desc1: "<&7>Peluang mending (mancing dan villager) +10 poin."
            desc2: ""
        mending_nerf:
            name: "<&8><&l>Itu Hanya Mitos"
            scope: both
            kind: negative
            weight: 4
            duration: 30m
            bar: white
            icon: book
            desc1: "<&7>Peluang mending (mancing dan villager) -15 poin."
            desc2: ""
        lootbox_event:
            name: "<&6><&l>Lootbox Drop"
            scope: both
            kind: positive
            weight: 8
            duration: 20m
            bar: yellow
            icon: heart_of_the_sea
            desc1: "<&7>Monster punya 4% peluang menjatuhkan Lootbox."
            desc2: "<&7>Klik kanan Lootbox untuk membukanya."
        freezing_cold:
            name: "<&3><&l>Brrrr... Dingin Sekali"
            scope: both
            kind: negative
            weight: 4
            duration: 35m
            bar: blue
            icon: powder_snow_bucket
            desc1: "<&7>Jauh dari api/lava/furnace = terkena freeze."
            desc2: ""
        starvation_curse:
            name: "<&4><&l>Kelaparan..."
            scope: both
            kind: negative
            weight: 3
            duration: 30m
            bar: red
            icon: rotten_flesh
            desc1: "<&7>Hunger III: rasa lapar meningkat drastis."
            desc2: ""
        divine_wrath:
            name: "<&5><&l>Tuhan Berkehendak Lain"
            scope: personal
            kind: negative
            weight: 4
            duration: 30m
            bar: purple
            icon: wither_rose
            desc1: "<&7>Bad Luck III dan villager menolak berdagang."
            desc2: ""
        reflected_damage:
            name: "<&c><&l>Senjata Makan Tuan"
            scope: both
            kind: negative
            weight: 4
            duration: 25m
            bar: red
            icon: shield
            desc1: "<&7>15% damage seranganmu memantul ke dirimu."
            desc2: ""
        plague_outbreak:
            name: "<&2><&l>WABAH"
            scope: global
            kind: negative
            weight: 3
            duration: 25m
            bar: green
            icon: zombie_head
            desc1: "<&7>Wabah menular dalam jarak 3 blok."
            desc2: "<&7>Minum susu untuk sembuh."
        world_slowness:
            name: "<&8><&l>Dunia di Pundakku"
            scope: both
            kind: negative
            weight: 4
            duration: 30m
            bar: white
            icon: anvil
            desc1: "<&7>Efek Slowness I untuk pemain."
            desc2: ""
        ghost_town:
            name: "<&d><&l>Dimana Makhluk Lain?"
            scope: global
            kind: positive
            weight: 6
            duration: 10m
            bar: pink
            icon: barrier
            desc1: "<&7>Monster tidak muncul secara natural."
            desc2: ""
        fragile_gear:
            name: "<&c><&l>Lah Kok Cepat Hancur?"
            scope: both
            kind: negative
            weight: 4
            duration: 30m
            bar: red
            icon: flint
            desc1: "<&7>Durability alat habis 2x lebih cepat."
            desc2: ""
        pe_midas_touch:
            name: "<&6><&l>Midas Touch"
            scope: personal
            kind: positive
            weight: 5
            duration: 10m
            bar: yellow
            icon: raw_gold
            desc1: "<&7>Ore yang ditambang langsung jadi ingot dan dikali 2."
            desc2: "<&7>Berakhir setelah 32 ore atau 10 menit."
        pe_guardian_angel:
            name: "<&f><&l>Guardian Angel"
            scope: personal
            kind: positive
            weight: 4
            duration: 20m
            bar: white
            icon: totem_of_undying
            desc1: "<&7>Damage fatal pertama: HP pulih 50%, Resistance III 5 detik."
            desc2: "<&7>Sekali pakai."
        pe_blood_thirst:
            name: "<&4><&l>Blood Thirst"
            scope: personal
            kind: positive
            weight: 5
            duration: 20m
            bar: red
            icon: redstone
            desc1: "<&7>Membunuh mob/player memulihkan 2 hati."
            desc2: "<&7>Berakhir setelah 15 kill atau kamu mati."
        pe_silent_stealth:
            name: "<&7><&l>Silent Stealth"
            scope: personal
            kind: positive
            weight: 4
            duration: 15m
            bar: white
            icon: phantom_membrane
            desc1: "<&7>Invisibility penuh, tidak memicu Sculk Sensor/Warden."
            desc2: ""
        pe_ghost_phasing:
            name: "<&b><&l>Ghost Phasing"
            scope: personal
            kind: positive
            weight: 5
            duration: 10m
            bar: blue
            icon: phantom_membrane
            desc1: "<&7>Kebal Fall Damage dan Suffocation."
            desc2: ""
        pe_titan_will:
            name: "<&e><&l>Titan Will"
            scope: personal
            kind: positive
            weight: 4
            duration: 20m
            bar: yellow
            icon: golden_apple
            desc1: "<&7>Absorption IV dan kebal knockback."
            desc2: "<&7>Berakhir saat hati kuning habis."
        pe_celestial_fishing:
            name: "<&b><&l>Celestial Fishing"
            scope: personal
            kind: positive
            weight: 5
            duration: 15m
            bar: blue
            icon: fishing_rod
            desc1: "<&7>Mancing super cepat, 50% peluang treasure."
            desc2: "<&7>Berakhir setelah 10 tangkapan."
        pe_lightning_striker:
            name: "<&e><&l>Lightning Striker"
            scope: personal
            kind: positive
            weight: 4
            duration: 15m
            bar: yellow
            icon: trident
            desc1: "<&7>Critical hit memanggil petir ke target."
            desc2: "<&7>Berakhir setelah 10 critical hit."
        pe_overclock_worker:
            name: "<&a><&l>Overclock Worker"
            scope: personal
            kind: positive
            weight: 6
            duration: 8m
            bar: green
            icon: diamond_pickaxe
            desc1: "<&7>Haste III, alat tidak berkurang durability."
            desc2: ""
        pe_soul_resonance:
            name: "<&d><&l>Soul Resonance"
            scope: personal
            kind: positive
            weight: 5
            duration: 10m
            bar: pink
            icon: experience_bottle
            desc1: "<&7>EXP yang didapat dikali 5."
            desc2: "<&7>Berakhir setelah +30 level atau 10 menit."
        pe_kamikaze_corpse:
            name: "<&4><&l>Kamikaze Corpse"
            scope: personal
            kind: negative
            weight: 2
            duration: 1h
            bar: red
            icon: tnt
            desc1: "<&7>Saat kamu mati, mayatmu meledak dahsyat."
            desc2: "<&7>Hangus setelah mati 1 kali."
        pe_leaky_inventory:
            name: "<&c><&l>Leaky Inventory"
            scope: personal
            kind: negative
            weight: 4
            duration: 10m
            bar: red
            icon: dropper
            desc1: "<&7>25% peluang item hotbar jatuh saat kena damage."
            desc2: ""
        pe_paranoia_stalker:
            name: "<&5><&l>Paranoia Stalker"
            scope: personal
            kind: negative
            weight: 5
            duration: 15m
            bar: purple
            icon: sculk_sensor
            desc1: "<&7>Suara mencekam acak dan blindness singkat."
            desc2: "<&7>Hilang jika kamu tidur."
        pe_glass_cannon:
            name: "<&c><&l>Glass Cannon"
            scope: personal
            kind: negative
            weight: 3
            duration: 1h
            bar: red
            icon: glass
            desc1: "<&7>Damage seranganmu 2x, tapi max HP jadi 5 hati."
            desc2: "<&7>Aktif sampai mati."
        pe_heavy_anchor:
            name: "<&8><&l>Heavy Anchor"
            scope: personal
            kind: negative
            weight: 4
            duration: 10m
            bar: white
            icon: anvil
            desc1: "<&7>Tidak bisa melompat, tenggelam di air."
            desc2: ""
        pe_hunger_curse:
            name: "<&6><&l>Hunger Curse"
            scope: personal
            kind: negative
            weight: 5
            duration: 12m
            bar: yellow
            icon: rotten_flesh
            desc1: "<&7>Lapar 3x lebih cepat, makanan -50% efek."
            desc2: ""
        pe_fragile_equipment:
            name: "<&c><&l>Fragile Equipment"
            scope: personal
            kind: negative
            weight: 4
            duration: 10m
            bar: red
            icon: shears
            desc1: "<&7>Durability armor/senjata berkurang 5x lebih cepat."
            desc2: "<&7>Berakhir jika salah satu hancur."
        pe_blood_scent:
            name: "<&4><&l>Blood Scent"
            scope: personal
            kind: negative
            weight: 4
            duration: 10m
            bar: red
            icon: rotten_flesh
            desc1: "<&7>Monster dalam 40 blok tahu lokasimu."
            desc2: ""
        pe_arachnophobia:
            name: "<&2><&l>Arachnophobia"
            scope: personal
            kind: negative
            weight: 3
            duration: 20m
            bar: green
            icon: spider_eye
            desc1: "<&7>Jalan di tanah: 15% spawn Cave Spider beracun."
            desc2: "<&7>Berakhir setelah membunuh 8 Cave Spider."
        pe_misfortune_punish:
            name: "<&8><&l>Misfortune Punish"
            scope: personal
            kind: negative
            weight: 2
            duration: 15m
            bar: white
            icon: raw_iron
            desc1: "<&7>Buff positif hilang, dapat Bad Omen V + Unluck III."
            desc2: "<&7>Berakhir di desa atau 15 menit."
        pe_gravity_anomaly:
            name: "<&b><&l>Gravity Anomaly"
            scope: personal
            kind: chaos
            weight: 4
            duration: 10m
            bar: blue
            icon: feather
            desc1: "<&7>Lompatan super tinggi, jalan di darat melambat."
            desc2: ""
        pe_cursed_magnet:
            name: "<&5><&l>Cursed Magnet"
            scope: personal
            kind: chaos
            weight: 4
            duration: 8m
            bar: purple
            icon: magma_cream
            desc1: "<&7>Item dan EXP orb tersedot ke arahmu dari 12 blok."
            desc2: ""
        pe_random_teleport:
            name: "<&d><&l>Random Teleport"
            scope: personal
            kind: chaos
            weight: 3
            duration: 20m
            bar: pink
            icon: ender_pearl
            desc1: "<&7>Kena damage = teleport acak 10-30 blok."
            desc2: "<&7>Berakhir setelah 8 kali."
        pe_explosive_sneeze:
            name: "<&6><&l>Explosive Sneeze"
            scope: personal
            kind: chaos
            weight: 3
            duration: 10m
            bar: yellow
            icon: firework_star
            desc1: "<&7>HP berkurang = dorongan ke sekitarmu (tanpa damage)."
            desc2: ""
        pe_swapper_punch:
            name: "<&e><&l>Swapper Punch"
            scope: personal
            kind: chaos
            weight: 4
            duration: 15m
            bar: yellow
            icon: ender_eye
            desc1: "<&7>Memukul = bertukar posisi dengan target."
            desc2: "<&7>Berakhir setelah 5 kali tukar."
        pe_inventory_shuffle:
            name: "<&d><&l>Inventory Shuffle"
            scope: personal
            kind: chaos
            weight: 3
            duration: 10m
            bar: pink
            icon: chest
            desc1: "<&7>Membunuh entitas mengacak inventory-mu."
            desc2: "<&7>Berakhir setelah 10 kill atau 10 menit."
        pe_dimensional_glitch:
            name: "<&1><&l>Dimensional Glitch"
            scope: personal
            kind: chaos
            weight: 2
            duration: 7m
            bar: purple
            icon: ender_eye
            desc1: "<&7>Cuaca dan waktu di layarmu berubah-ubah."
            desc2: "<&7>Kontrol jalan tidak bisa dibalik (bukan hal yang Denizen bisa lakukan)."
        pe_hot_potato:
            name: "<&6><&l>Hot Potato"
            scope: personal
            kind: chaos
            weight: 3
            duration: 2m
            bar: yellow
            icon: tnt
            desc1: "<&7>Kamu pegang TNT menyala, pukul pemain lain untuk oper."
            desc2: "<&7>Meledak jika 30 detik habis di tanganmu."
        pe_shapeshifter_curse:
            name: "<&5><&l>Shapeshifter Curse"
            scope: personal
            kind: chaos
            weight: 2
            duration: 10m
            bar: purple
            icon: egg
            desc1: "<&7>Skala tubuh dan kecepatanmu berubah tiap 30 detik."
            desc2: "<&7>Wujud visual tidak berubah (butuh plugin disguise)."
        pe_chorus_diet:
            name: "<&d><&l>Chorus Diet"
            scope: personal
            kind: chaos
            weight: 3
            duration: 12m
            bar: pink
            icon: chorus_fruit
            desc1: "<&7>Makan apa pun = efeknya seperti Chorus Fruit."
            desc2: ""

# Angka mentah untuk 30 event global/both (sebelumnya tertanam di kode).
event_global_config:
    type: data
    acid_water:
        poison_amplifier: 0
        poison_duration: 5s
        nausea_amplifier: 0
        nausea_duration: 8s
    pollution:
        poison_amplifier: 0
        poison_duration: 3s
        safe_helmet_contains: glass
    freezing_cold:
        freeze_add: 30
        freeze_max: 160
        heat_radius: 4
    starvation_curse:
        hunger_amplifier: 2
    lucky_person:
        luck_amplifier: 1
    divine_wrath:
        unluck_amplifier: 2
    world_faster:
        speed_amplifier: 1
        haste_amplifier: 1
    slowest_world:
        slowness_amplifier: 1
        mining_fatigue_amplifier: 0
    world_slowness:
        slowness_amplifier: 0
    plague_outbreak:
        infect_radius: 3
        infect_chance: 15
        sick_duration: 8m
        weakness_amplifier: 0
        nausea_every_ticks: 10
    creeper_birthday:
        effect_duration: 10m
        effect_amplifier: 1
        effect_pool:
        - speed
        - slowness
        - haste
        - mining_fatigue
        - strength
        - instant_health
        - instant_damage
        - jump_boost
        - nausea
        - regeneration
        - resistance
        - fire_resistance
        - water_breathing
        - invisibility
        - blindness
        - night_vision
        - hunger
        - weakness
        - poison
        - wither
        - health_boost
        - absorption
        - saturation
        - glowing
        - levitation
        - luck
        - unluck
        - slow_falling
        - conduit_power
        - dolphins_grace
        - darkness
        - wind_charged
        - weaving
        - oozing
        - infested

    gear_up:
        diamond_chance: 50
        iron_chance: 25
        chainmail_chance: 15
        mob_list:
        - zombie
        - husk
        - drowned
        - zombie_villager
        - skeleton
        - stray
        - bogged
        - wither_skeleton
    blast_furnace_danger:
        explode_chance: 3
        explode_power: 1.5
    watch_out_bombs:
        explode_chance: 3
        explode_power: 1.0
        block_list:
        - stone
        - deepslate
        - cobblestone
        - andesite
        - diorite
        - granite
        - tuff
        - netherrack
    tax_system:
        tax_chance: 12
    double_drop:
        multiplier: 2
    damage_bonus:
        multiplier: 1.5
    reflected_damage:
        reflect_percent: 0.15
    fragile_gear:
        durability_multiplier: 2
    lootbox_event:
        drop_chance: 2
    totem_of_life:
        drop_chance: 2

# Angka mentah untuk 25 event personal.
pe_config:
    type: data
    midas_touch:
        ore_limit: 32
        duration: 10m
    guardian_angel:
        duration: 20m
    blood_thirst:
        heal_amount: 4
        kill_limit: 15
        duration: 20m
    silent_stealth:
        duration: 15m
    ghost_phasing:
        duration: 10m
    titan_will:
        absorption_amplifier: 3
        duration: 20m
        max_health: 20.0
    celestial_fishing:
        catch_limit: 10
        treasure_chance: 50
        duration: 15m
    lightning_striker:
        crit_limit: 10
        duration: 15m
    overclock_worker:
        duration: 8m
    soul_resonance:
        xp_multiplier: 5
        level_limit: 30
        duration: 10m
    kamikaze_corpse:
        duration: 1h
    leaky_inventory:
        drop_chance: 25
        duration: 10m
    paranoia_stalker:
        duration: 15m
        trigger_chance: 5
        blindness_chance: 40
    glass_cannon:
        damage_multiplier: 2
        max_health: 10.0
        duration: 1h
    heavy_anchor:
        duration: 10m
    hunger_curse:
        duration: 12m
    fragile_equipment:
        durability_multiplier: 5
        duration: 10m
    blood_scent:
        radius: 40
        duration: 10m
    arachnophobia:
        spawn_chance: 15
        spider_limit: 8
        duration: 20m
    misfortune_punish:
        max_duration: 15m
        village_radius: 25
    gravity_anomaly:
        duration: 10m
    cursed_magnet:
        radius: 12
        duration: 8m
    random_teleport:
        min_radius: 10
        max_radius: 30
        trigger_limit: 8
        duration: 20m
    explosive_sneeze:
        push_radius: 6
        push_distance: 8
        duration: 10m
    swapper_punch:
        swap_limit: 5
        duration: 15m
    inventory_shuffle:
        kill_limit: 10
        duration: 10m
    dimensional_glitch:
        duration: 7m
    hot_potato:
        fuse: 30s
    shapeshifter_curse:
        duration: 10m
    chorus_diet:
        duration: 12m


# =============================================================================
#  5. GUI /eventlist DAN /eventadmin
# =============================================================================
eventlist_command:
    type: command
    name: eventlist
    aliases:
    - event
    debug: false
    description: Melihat event yang sedang aktif dan keterangan semua event.
    usage: /eventlist [halaman]
    script:
    - if !<player.is_player||false>:
        - stop
    - define page <context.args.get[1]||1>
    - if !<[page].is_integer> || <[page]> < 1:
        - narrate "<&c>Halaman harus berupa angka positif."
        - stop
    - run event_gui_open def.page:<[page]>

event_list_gui:
    type: inventory
    inventory: chest
    title: <&8><&l>Event Server
    size: 54
    gui: true
    slots:
    - [] [] [] [] [] [] [] [] []
    - [] [] [] [] [] [] [] [] []
    - [] [] [] [] [] [] [] [] []
    - [] [] [] [] [] [] [] [] []
    - [] [] [] [] [] [] [] [] []
    - [] [] [] [] [] [] [] [] []

event_category_gui:
    type: inventory
    inventory: chest
    title: <&8><&l>Kategori Event
    size: 54
    gui: true
    slots:
    - [] [] [] [] [] [] [] [] []
    - [] [] [] [] [] [] [] [] []
    - [] [] [] [] [] [] [] [] []
    - [] [] [] [] [] [] [] [] []
    - [] [] [] [] [] [] [] [] []
    - [] [] [] [] [] [] [] [] []

event_gui_open:
    type: task
    debug: false
    definitions: page
    script:
    - define cfg <script[event_config]>
    - define ids <[cfg].data_key[event_ids]>
    - define pages <[ids].size.div[44].round_up>
    - define page <[page]||1>
    - if <[page]> > <[pages]>:
        - narrate "<&c>Halaman hanya tersedia sampai <[pages]>."
        - stop
    - define inv <inventory[event_list_gui]>
    - define g <server.flag[active_global_event]||none>
    - define q <player.flag[active_personal_event]||none>
    - define lore <list>
    - if <[g]> != none:
        - define "lore:->:<&a>Aktif: <[cfg].parsed_key[all_events.<[g]>.name]>"
        - define "lore:->:<&7>Sisa: <&f><server.flag_expiration[active_global_event].from_now.formatted>"
    - else if <server.has_flag[global_event_cooldown]>:
        - define "lore:->:<&e>Masa tenang"
        - define "lore:->:<&7>Event berikutnya: <&f><server.flag_expiration[global_event_cooldown].from_now.formatted>"
    - else:
        - define "lore:->:<&7>Menunggu event global berikutnya"
    - inventory set d:<[inv]> slot:3 o:<item[clock].with[display=<&6><&l>Event Global;lore=<[lore]>]>
    - define lore <list>
    - define "lore:->:<&7>Event global berlaku untuk semua pemain."
    - define "lore:->:<&7>Event personal hanya berlaku untukmu."
    - inventory set d:<[inv]> slot:5 o:<item[book].with[display=<&e><&l>Tentang Event;lore=<[lore]>]>
    - define lore <list>
    - if <[q]> != none:
        - define "lore:->:<&a>Aktif: <[cfg].parsed_key[all_events.<[q]>.name]>"
        - define "lore:->:<&7>Sisa: <&f><player.flag_expiration[active_personal_event].from_now.formatted>"
    - else if <player.has_flag[personal_event_cooldown]>:
        - define "lore:->:<&e>Menunggu event personal berikutnya"
        - define "lore:->:<&7>Sekitar: <&f><player.flag_expiration[personal_event_cooldown].from_now.formatted>"
    - else:
        - define "lore:->:<&7>Event personal akan segera datang"
    - inventory set d:<[inv]> slot:7 o:<item[emerald].with[display=<&b><&l>Event Personal;lore=<[lore]>]>
    - define start <[page].sub[1].mul[44].add[1]>
    - define end <[start].add[43]>
    - if <[end]> > <[ids].size>:
        - define end <[ids].size>
    - define slot 10
    - foreach <[ids].get[<[start]>].to[<[end]>]> as:id:
        - define base all_events.<[id]>
        - define name <[cfg].parsed_key[<[base]>.name]>
        - define kind <[cfg].data_key[<[base]>.kind]>
        - define scope <[cfg].data_key[<[base]>.scope]>
        - if <[kind]> == positive:
            - define kind_text "<&a>Positif"
        - else if <[kind]> == negative:
            - define kind_text "<&c>Negatif"
        - else if <[kind]> == chaos:
            - define kind_text "<&e>Chaos"
        - else if <[kind]> == special:
            - define kind_text "<&b>Special"
        - else if <[kind]> == bizarre:
            - define kind_text "<&5>Bizarre"
        - else:
            - define kind_text "<&7><[kind]>"
        - if <[scope]> == global:
            - define scope_text Global
        - else if <[scope]> == personal:
            - define scope_text Personal
        - else:
            - define scope_text "Global dan Personal"
        - define rarity <proc[event_rarity].context[<[scope]>|<[id]>]>
        - if <[scope]> == both:
            - define global_chance <proc[event_chance].context[global|<[id]>]>
            - define personal_chance <proc[event_chance].context[personal|<[id]>]>
            - define chance_text "<&7>Peluang Global/Personal: <&f><[global_chance]>% <&8>/ <&f><[personal_chance]>%"
        - else:
            - define chance <proc[event_chance].context[<[scope]>|<[id]>]>
            - define chance_text "<&7>Peluang: <&f><[chance]>%"
        - define lore <list>
        - define "lore:->:<&7>Tipe: <[kind_text]> <&8>| <&7>Cakupan: <&f><[scope_text]>"
        - define "lore:->:<&7>Rarity: <[rarity]> <&8>| <[chance_text]>"
        - define "lore:->:<&7>Durasi global: <&f><[cfg].data_key[<[base]>.duration]>"
        - define "lore:->:<&r>"
        - define "lore:->:<&f><[cfg].parsed_key[<[base]>.desc1]>"
        - define d2 <[cfg].parsed_key[<[base]>.desc2]||>
        - if <[d2].length> > 0:
            - define "lore:->:<&f><[d2]>"
        - if <[g]> == <[id]>:
            - define "lore:->:<&r>"
            - define "lore:->:<&a><&l>AKTIF (global) <&7>sisa <&f><server.flag_expiration[active_global_event].from_now.formatted>"
        - if <[q]> == <[id]>:
            - define "lore:->:<&r>"
            - define "lore:->:<&b><&l>AKTIF (personal) <&7>sisa <&f><player.flag_expiration[active_personal_event].from_now.formatted>"
        - define icon <[cfg].data_key[<[base]>.icon]>
        - inventory set d:<[inv]> slot:<[slot]> o:<item[<[icon]>].with[display=<[name]>;lore=<[lore]>]>
        - define slot:++
    - define arrow_lore <list>
    - if <[page]> == 1:
        - define "arrow_lore:->:<&7>Buka halaman berikutnya: /event 2"
    - else:
        - define "arrow_lore:->:<&c>Halaman berikutnya belum tersedia."
    - inventory set d:<[inv]> slot:54 o:<item[arrow].with[display=<&e>Halaman <[page]>/<[pages]>;lore=<[arrow_lore]>]>
    - if <[page]> > 1:
        - inventory set d:<[inv]> slot:1 o:<item[arrow].with[display=<&a>Kembali ke Halaman Sebelumnya;lore=<list[<&7>Kembali ke halaman <[page].sub[1]>.]>]>
    - flag player event_gui_page:<[page]>
    - inventory open d:<[inv]>

event_category_open:
    type: task
    debug: false
    definitions: category|page
    script:
    - define cfg <script[event_config]>
    - define ids <[cfg].data_key[event_ids]>
    - define category <[category]||global>
    - define filtered_ids <list>
    - foreach <[ids]> as:id:
        - define scope <[cfg].data_key[all_events.<[id]>.scope]>
        - if <[category]> == global:
            - if <[scope]> != personal:
                - define "filtered_ids:->:<[id]>"
        - else:
            - if <[scope]> != global:
                - define "filtered_ids:->:<[id]>"
    - define pages <[filtered_ids].size.div[44].round_up>
    - define page <[page]||1>
    - if <[page]> > <[pages]>:
        - narrate "<&c>Halaman kategori ini belum tersedia."
        - stop
    - define inv <inventory[event_category_gui]>
    - define category_name "Event Global"
    - define category_icon clock
    - if <[category]> == personal:
        - define category_name "Event Personal"
        - define category_icon emerald
    - define category_lore <list>
    - define "category_lore:->:<&7>Daftar event dalam kategori ini."
    - inventory set d:<[inv]> slot:1 o:<item[barrier].with[display=<&c>Kembali ke event;lore=<list[<&7>Kembali ke daftar event utama.]>]>
    - inventory set d:<[inv]> slot:5 o:<item[<[category_icon]>].with[display=<&e><&l><[category_name]>;lore=<[category_lore]>]>
    - inventory set d:<[inv]> slot:54 o:<item[arrow].with[display=<&e>Halaman berikutnya;lore=<list[<&7>Belum tersedia.]>]>
    - if <[page]> > 1:
        - inventory set d:<[inv]> slot:9 o:<item[spectral_arrow].with[display=<&e>Halaman sebelumnya;lore=<list[<&7>Kembali ke halaman sebelumnya.]>]>
    - define start <[page].sub[1].mul[44].add[1]>
    - define end <[start].add[43]>
    - if <[end]> > <[filtered_ids].size>:
        - define end <[filtered_ids].size>
    - define slot 10
    - foreach <[filtered_ids].get[<[start]>].to[<[end]>]> as:id:
        - define base all_events.<[id]>
        - define name <[cfg].parsed_key[<[base]>.name]>
        - define kind <[cfg].data_key[<[base]>.kind]>
        - define scope <[cfg].data_key[<[base]>.scope]>
        - if <[kind]> == positive:
            - define kind_text "<&a>Positif"
        - else if <[kind]> == negative:
            - define kind_text "<&c>Negatif"
        - else if <[kind]> == chaos:
            - define kind_text "<&e>Chaos"
        - else if <[kind]> == special:
            - define kind_text "<&b>Special"
        - else if <[kind]> == bizarre:
            - define kind_text "<&5>Bizarre"
        - else:
            - define kind_text "<&7><[kind]>"
        - if <[scope]> == global:
            - define scope_text Global
        - else if <[scope]> == personal:
            - define scope_text Personal
        - else:
            - define scope_text "Global dan Personal"
        - define rarity <proc[event_rarity].context[<[category]>|<[id]>]>
        - define chance <proc[event_chance].context[<[category]>|<[id]>]>
        - define lore <list>
        - define "lore:->:<&7>Tipe: <[kind_text]> <&8>| <&7>Cakupan: <&f><[scope_text]>"
        - define "lore:->:<&7>Rarity: <[rarity]> <&8>| <&7>Peluang: <&f><[chance]>%"
        - define "lore:->:<&7>Durasi global: <&f><[cfg].data_key[<[base]>.duration]>"
        - define "lore:->:<&r>"
        - define "lore:->:<&f><[cfg].parsed_key[<[base]>.desc1]>"
        - define d2 <[cfg].parsed_key[<[base]>.desc2]||>
        - if <[d2].length> > 0:
            - define "lore:->:<&f><[d2]>"
        - if <server.flag[active_global_event]||none> == <[id]>:
            - define "lore:->:<&r>"
            - define "lore:->:<&a><&l>AKTIF (global) <&7>sisa <&f><server.flag_expiration[active_global_event].from_now.formatted>"
        - if <player.flag[active_personal_event]||none> == <[id]>:
            - define "lore:->:<&r>"
            - define "lore:->:<&b><&l>AKTIF (personal) <&7>sisa <&f><player.flag_expiration[active_personal_event].from_now.formatted>"
        - define icon <[cfg].data_key[<[base]>.icon]>
        - inventory set d:<[inv]> slot:<[slot]> o:<item[<[icon]>].with[display=<[name]>;lore=<[lore]>]>
        - define slot:++
    - flag player event_category:<[category]>
    - flag player event_category_page:<[page]>
    - inventory open d:<[inv]>

event_gui_handler:
    type: world
    debug: false
    events:
        on player clicks in event_list_gui:
        - if <context.slot> == 1 && <player.flag[event_gui_page]||1> > 1:
            - inventory close
            - run event_gui_open def.page:<player.flag[event_gui_page].sub[1]>
        - else if <context.slot> == 3:
            - inventory close
            - run event_category_open def.category:global def.page:1
        - else if <context.slot> == 7:
            - inventory close
            - run event_category_open def.category:personal def.page:1
        - else if <context.slot> == 54:
            - if <player.flag[event_gui_page]||1> == 1:
                - inventory close
                - run event_gui_open def.page:2
            - else:
                - narrate "<&c>Halaman berikutnya belum tersedia."

event_category_handler:
    type: world
    debug: false
    events:
        on player clicks in event_category_gui:
        - if <context.slot> == 1:
            - inventory close
            - run event_gui_open def.page:<player.flag[event_gui_page]||1>
        - else if <context.slot> == 9:
            - define page <player.flag[event_category_page]||1>
            - if <[page]> > 1:
                - inventory close
                - run event_category_open def.category:<player.flag[event_category]||global> def.page:<[page].sub[1]>
        - else if <context.slot> == 54:
            - if <player.flag[event_category_page]||1> == 1:
                - inventory close
                - run event_category_open def.category:<player.flag[event_category]||global> def.page:2
            - else:
                - narrate "<&c>Halaman berikutnya belum tersedia."

eventadmin_command:
    type: command
    name: eventadmin
    debug: false
    description: Admin sistem event.
    usage: /eventadmin help | status | start global [id] | stop global | start personal pemain [id] | stop personal pemain | give global/personal pemain [jumlah]
    permission: brutal.event.admin
    permission message: <&c>Kamu tidak punya izin untuk ini (<[permission]>).
    script:
    - define cfg <script[event_config]>
    - define a1 <context.args.get[1]||help>
    - define a2 <context.args.get[2]||none>
    - if <[a1]> == help:
        - narrate "<&6><&l>Panduan Event Admin <&8>| <&7>Izin: brutal.event.admin"
        - narrate "<&e>/eventadmin status <&8>- <&7>Lihat status event global dan daftar ID yang tersedia."
        - narrate "<&e>/eventadmin start global [id] <&8>- <&7>Mulai event global; tanpa ID, event dipilih acak."
        - narrate "<&e>/eventadmin stop global <&8>- <&7>Hentikan event global yang sedang aktif."
        - narrate "<&e>/eventadmin start personal pemain [id] <&8>- <&7>Berikan event personal; tanpa ID, event dipilih acak."
        - narrate "<&e>/eventadmin stop personal pemain <&8>- <&7>Hentikan event personal pemain."
        - narrate "<&e>/eventadmin give global/personal pemain [jumlah] <&8>- <&7>Berikan booster; jumlah default 1 dan batasnya 64."
        - narrate "<&7>ID harus cocok dengan cakupan event. Gunakan /eventadmin status untuk melihat ID yang tersedia."
        - stop
    - if <[a1]> == status:
        - if <server.has_flag[global_event_started]>:
            - narrate "<&6>Global: <&f><server.flag[global_event_current_id]||?> <&7>sisa <&f><server.flag_expiration[active_global_event].from_now.formatted||habis>"
        - else if <server.has_flag[global_event_cooldown]>:
            - narrate "<&6>Global: <&7>masa tenang, berikutnya <&f><server.flag_expiration[global_event_cooldown].from_now.formatted>"
        - else:
            - narrate "<&6>Global: <&7>menunggu giliran"
        - narrate "<&7>ID event: <&f><[cfg].data_key[event_ids].separated_by[, ]>"
        - stop
    - if <[a1]> == start && <[a2]> == global:
        - if <server.has_flag[global_event_started]>:
            - narrate "<&c>Event global masih berjalan. Pakai /eventadmin stop global."
            - stop
        - define id <context.args.get[3]||none>
        - if <[id]> != none && !<[cfg].data_key[event_ids].contains[<[id]>]>:
            - narrate "<&c>ID event tidak dikenal. Lihat /eventadmin status."
            - stop
        - define event_scope <[cfg].data_key[all_events.<[id]>.scope]||both>
        - if <[id]> != none && <[event_scope]> != both && <[event_scope]> != global:
            - narrate "<&c>Event itu bukan event global."
            - stop
        - run event_global_start def.forced:<[id]>
        - stop
    - if <[a1]> == stop && <[a2]> == global:
        - if !<server.has_flag[global_event_started]>:
            - narrate "<&7>Tidak ada event global yang berjalan."
            - stop
        - run event_global_finish def.reason:admin
        - stop
    - if <[a1]> == start && <[a2]> == personal:
        - define target <server.match_player[<context.args.get[3]||>]||null>
        - if <[target]> == null:
            - narrate "<&c>Pemain tidak ditemukan."
            - stop
        - define id <context.args.get[4]||none>
        - if <[id]> != none && !<[cfg].data_key[event_ids].contains[<[id]>]>:
            - narrate "<&c>ID event tidak dikenal."
            - stop
        - define event_scope <[cfg].data_key[all_events.<[id]>.scope]||both>
        - if <[id]> != none && <[event_scope]> != both && <[event_scope]> != personal:
            - narrate "<&c>Event itu bukan event personal."
            - stop
        - if <[target].has_flag[active_personal_event]>:
            - run event_personal_finish def:<[target]>|<element[diganti admin]>
        - run event_personal_assign def.p:<[target]> def.forced:<[id]>
        - stop
    - if <[a1]> == stop && <[a2]> == personal:
        - define target <server.match_player[<context.args.get[3]||>]||null>
        - if <[target]> == null:
            - narrate "<&c>Pemain tidak ditemukan."
            - stop
        - run event_personal_finish def:<[target]>|<element[dihentikan admin]>
        - stop
    - if <[a1]> == give && <list[global|personal].contains[<[a2]>]>:
        - define target <server.match_player[<context.args.get[3]||>]||null>
        - if <[target]> == null:
            - narrate "<&c>Pemain tidak ditemukan."
            - stop
        - define amount <context.args.get[4]||1>
        - if !<[amount].is_integer> || <[amount]> < 1 || <[amount]> > 64:
            - narrate "<&c>Jumlah harus angka 1 sampai 64."
            - stop
        - give <[a2]>_booster_item quantity:<[amount]> to:<[target].inventory>
        - narrate "<&a>Memberi <[amount]> <[a2]> booster ke <[target].name>."
        - stop
    - narrate "<&c>Subcommand tidak dikenal. Gunakan /eventadmin help untuk panduan."


# =============================================================================
#  6. ITEM: BOOSTER, LOOTBOX, PENGUNCIAN ITEM
# =============================================================================
global_booster_item:
    type: item
    material: nether_star
    display name: <&6><&l>Global Event Booster
    lore:
    - <&7>Klik kanan pada blok untuk memicu
    - <&7>event global secara instan.

personal_booster_item:
    type: item
    material: emerald
    display name: <&b><&l>Personal Event Booster
    lore:
    - <&7>Klik kanan pada blok untuk memicu
    - <&7>event personal untuk dirimu.

lootbox_item:
    type: item
    material: heart_of_the_sea
    display name: <&6><&l>Lootbox
    lore:
    - <&7>Klik kanan pada blok untuk membukanya.

booster_handler:
    type: world
    debug: false
    events:
        on player right clicks block with:global_booster_item using:hand:
        - if <server.has_flag[global_event_started]>:
            - narrate "<&c>Event global masih berjalan."
            - stop
        - take iteminhand quantity:1
        - run event_global_start
        - announce "<&6><&l>[BOOSTER] <&e><player.name> mengaktifkan Global Booster!"
        on player right clicks block with:personal_booster_item using:hand:
        - if <player.has_flag[active_personal_event]>:
            - narrate "<&c>Event personal milikmu masih berjalan."
            - stop
        - take iteminhand quantity:1
        - run event_personal_assign def.p:<player>
        on player right clicks block with:lootbox_item using:hand:
        - take iteminhand quantity:1
        - define parts <script[event_config].data_key[lootbox_rewards].random.split[:]>
        - define amount <util.random.int[<[parts].get[2]>].to[<[parts].get[3]>]>
        - give <[parts].get[1]> quantity:<[amount]>
        - narrate "<&6>Lootbox berisi <&f><[amount]>x <[parts].get[1].replace[_].with[ ]><&6>!"

pe_item_lock:
    type: world
    debug: false
    events:
        on player right clicks block with:global_booster_item|personal_booster_item|lootbox_item:
        - define mat <context.location.material.name>
        - if <list[anvil|chipped_anvil|damaged_anvil|grindstone|enchanting_table].contains[<[mat]>]>:
            - determine cancelled
        on player clicks in furnace:
        - if <context.item> matches global_booster_item|personal_booster_item|lootbox_item:
            - determine cancelled
        on player drops item:
        - if <context.item> matches global_booster_item|personal_booster_item|lootbox_item:
            - narrate "<&c>Item ini tidak bisa dibuang."
            - determine cancelled


# =============================================================================
#  7. LISTENER MEKANIK: 30 EVENT GLOBAL/BOTH
# =============================================================================
event_gameplay_listeners:
    type: world
    debug: false
    events:
        on entity dies:
        - if <context.entity.is_player||false> || <context.entity.entity_type> == evoker:
            - stop
        - define killer <context.damager||none>
        - define drops <context.drops>
        - define changed false
        - define gcfg <script[event_global_config]>
        - if <proc[event_active].context[double_drop|<[killer]>]>:
            - define result <list>
            - foreach <[drops]> as:it:
                - define result:->:<[it].with[quantity=<[it].quantity.mul[<[gcfg].data_key[double_drop.multiplier]>]>]>
            - define drops <[result]>
            - define changed true
        - if <[killer].is_player||false> && <context.entity.is_monster||false> && <proc[event_active].context[lootbox_event|<[killer]>]>:
            - if <util.random.int[1].to[100]> <= <[gcfg].data_key[lootbox_event.drop_chance]>:
                - define drops <[drops].include[<item[lootbox_item]>]>
                - define changed true
        - if <[changed]>:
            - determine <[drops]>
        on player damages entity:
        - define dmg <context.damage>
        - define changed false
        - define gcfg <script[event_global_config]>
        - if <proc[event_active].context[damage_bonus|<player>]>:
            - define dmg <[dmg].mul[<[gcfg].data_key[damage_bonus.multiplier]>]>
            - define changed true
        - if <player.flag[active_personal_event]||none> == pe_glass_cannon:
            - define dmg <[dmg].mul[<script[pe_config].data_key[glass_cannon.damage_multiplier]>]>
            - define changed true
        - if <proc[event_active].context[reflected_damage|<player>]>:
            - define back <[dmg].mul[<[gcfg].data_key[reflected_damage.reflect_percent]>]>
            - if <player.health> > <[back].add[1]>:
                - hurt <[back]> <player>
        - if <[changed]>:
            - determine <[dmg]>
        on player breaks block:
        - define gcfg <script[event_global_config]>
        - define mat <context.material.name>
        - define ore <[mat].ends_with[_ore]>
        - if <[ore]> && <proc[event_active].context[tax_system|<player>]>:
            - if <util.random.int[1].to[100]> <= <[gcfg].data_key[tax_system.tax_chance]>:
                - determine nothing
                - narrate "<&e>Pajak Negara mengambil hasil tambangmu!"
                - stop
        - if <[ore]> || <[gcfg].data_key[watch_out_bombs.block_list].contains[<[mat]>]>:
            - if <proc[event_active].context[watch_out_bombs|<player>]> && <util.random.int[1].to[100]> <= <[gcfg].data_key[watch_out_bombs.explode_chance]>:
                - narrate "<&c><&l>PERINGATAN! <&e>TNT muncul di dekatmu dan akan meledak dalam 3 detik!"
                - spawn primed_tnt <context.location> save:watch_bomb
                - adjust <entry[watch_bomb].spawned_entity> fuse_ticks:60
        - if <[ore]> && <proc[event_active].context[fortune_goddess|<player>]>:
            - define dr <context.location.drops[<player.item_in_hand>]>
            - if !<[dr].is_empty>:
                - determine <[dr].include[<[dr]>]>
        on player item takes damage:
        - if <proc[event_active].context[fragile_gear|<player>]>:
            - determine <context.damage.mul[<script[event_global_config].data_key[fragile_gear.durability_multiplier]>].round_up>
        on player dies:
        - if <proc[event_active].context[no_item_drop|<player>]>:
            - determine no_drops
        on player right clicks villager:
        - if <proc[event_active].context[villager_strike|<player>]> || <proc[event_active].context[divine_wrath|<player>]>:
            - narrate "<&c>Villager menolak berdagang saat ini."
            - determine cancelled
        on player enters bed:
        - if <proc[event_active].context[eternal_night|null]>:
            - narrate "<&c>Dunia dikunci dalam malam abadi!"
            - determine cancelled
        on furnace|blast_furnace|smoker smelts item:
        - define gcfg <script[event_global_config]>
        - if <proc[event_active].context[blast_furnace_danger|null]> && <util.random.int[1].to[100]> <= <[gcfg].data_key[blast_furnace_danger.explode_chance]>:
            - announce "<&c><&l>PERINGATAN! <&e>Blast Furnace Danger terpicu. Ledakan dalam 2 detik di furnace yang sedang digunakan!"
            - wait 2s
            - explode power:<[gcfg].data_key[blast_furnace_danger.explode_power]> <context.location>
        on player consumes milk_bucket:
        - if <player.has_flag[plague_sick]>:
            - flag <player> plague_sick:!
            - narrate "<&a>Kamu sembuh dari wabah."
        on entity spawns:
        - if <context.entity.entity_type> == experience_orb && <proc[event_active].context[no_exp|null]>:
            - determine cancelled
            - stop
        - if <context.entity.is_monster||false> && <context.reason||none> == NATURAL && <proc[event_active].context[ghost_town|null]>:
            - determine cancelled
        after entity spawns:
        - define e <context.entity>
        - define t <[e].entity_type>
        - define gcfg <script[event_global_config]>
        - if <[t]> == creeper && <proc[event_active].context[creeper_birthday|null]>:
            - cast <[gcfg].data_key[creeper_birthday.effect_pool].random> <[e]> duration:<[gcfg].data_key[creeper_birthday.effect_duration]> amplifier:<[gcfg].data_key[creeper_birthday.effect_amplifier]>
        - if <[gcfg].data_key[gear_up.mob_list].contains[<[t]>]> && <proc[event_active].context[gear_up|null]>:
            - define armor_roll <util.random.int[1].to[100]>
            - define iron_threshold <[gcfg].data_key[gear_up.diamond_chance].add[<[gcfg].data_key[gear_up.iron_chance]>]>
            - define chainmail_threshold <[iron_threshold].add[<[gcfg].data_key[gear_up.chainmail_chance]>]>
            - if <[armor_roll]> <= <[gcfg].data_key[gear_up.diamond_chance]>:
                - equip <[e]> head:diamond_helmet chest:diamond_chestplate legs:diamond_leggings boots:diamond_boots
            - else if <[armor_roll]> <= <[iron_threshold]>:
                - equip <[e]> head:iron_helmet chest:iron_chestplate legs:iron_leggings boots:iron_boots
            - else if <[armor_roll]> <= <[chainmail_threshold]>:
                - equip <[e]> head:chainmail_helmet chest:chainmail_chestplate legs:chainmail_leggings boots:chainmail_boots
            - else:
                - equip <[e]> head:golden_helmet chest:golden_chestplate legs:golden_leggings boots:golden_boots


# =============================================================================
#  8. LISTENER MEKANIK: 25 EVENT PERSONAL
# =============================================================================
pe_listeners:
    type: world
    debug: false
    events:
        on player breaks block:
        - if !<context.material.name.ends_with[_ore]>:
            - stop
        - if <player.flag[active_personal_event]||none> != pe_midas_touch:
            - stop
        - define dr <context.location.drops[<player.item_in_hand>]>
        - define result <list>
        - foreach <[dr]> as:it:
            - define smelt <[it].smelt_result||<[it]>>
            - define result:->:<[smelt].with[quantity=<[smelt].quantity.mul[2]>]>
        - determine <[result]>
        - define ct <player.flag[pe_ct_midas]||0>
        - define ct <[ct].add[1]>
        - flag <player> pe_ct_midas:<[ct]>
        - if <[ct]> >= <script[pe_config].data_key[midas_touch.ore_limit]>:
            - flag <player> pe_ct_midas:!
            - run event_personal_finish def:<player>|<element[32 ore tercapai]>

        on player damaged:
        - define pe <player.flag[active_personal_event]||none>
        - if <[pe]> == pe_guardian_angel && !<player.has_flag[pe_guardian_used]>:
            - if <context.final_damage> >= <player.health>:
                - determine cancelled
                - flag <player> pe_guardian_used
                - adjust <player> health:<player.health_max.div[2]>
                - cast resistance <player> duration:5s amplifier:2
                - playeffect effect:totem_of_undying at:<player.location.add[0,1,0]> quantity:30 offset:0.5,0.5,0.5
                - run event_personal_finish def:<player>|<element[terpakai]>
                - stop
        - if <[pe]> == pe_leaky_inventory:
            - if <util.random.int[1].to[100]> <= <script[pe_config].data_key[leaky_inventory.drop_chance]>:
                - define it <player.item_in_hand>
                - if <[it]> !matches air:
                    - take iteminhand quantity:1
                    - drop <[it]> <player.location>
        - if <[pe]> == pe_random_teleport:
            - define min <script[pe_config].data_key[random_teleport.min_radius]>
            - define max <script[pe_config].data_key[random_teleport.max_radius]>
            - define dx <util.random.int[<[min]>].to[<[max]>].mul[<list[-1|1].random>]>
            - define dz <util.random.int[<[min]>].to[<[max]>].mul[<list[-1|1].random>]>
            - teleport <player> <player.location.add[<[dx]>,0,<[dz]>].highest.above[1]>
            - define ctr <player.flag[pe_ct_rtp]||0>
            - define ctr <[ctr].add[1]>
            - flag <player> pe_ct_rtp:<[ctr]>
            - if <[ctr]> >= <script[pe_config].data_key[random_teleport.trigger_limit]>:
                - flag <player> pe_ct_rtp:!
                - run event_personal_finish def:<player>|<element[8 kali teleport tercapai]>
        - if <[pe]> == pe_explosive_sneeze:
            - define rad <script[pe_config].data_key[explosive_sneeze.push_radius]>
            - define dist <script[pe_config].data_key[explosive_sneeze.push_distance]>
            - foreach <player.location.find_entities[living].within[<[rad]>].exclude[<player>]> as:e:
                - define dest <[e].location.add[<[e].location.sub[<player.location>].normalize.mul[<[dist]>]>]>
                - push <[e]> origin:<player.location> destination:<[dest]> speed:1.5 no_rotate no_damage

        on entity dies:
        - define killer <context.damager||none>
        - if <[killer].is_player||false>:
            - define kpe <[killer].flag[active_personal_event]||none>
            - if <[kpe]> == pe_blood_thirst:
                - heal <script[pe_config].data_key[blood_thirst.heal_amount]> <[killer]>
                - define ct <[killer].flag[pe_ct_bloodthirst]||0>
                - define ct <[ct].add[1]>
                - flag <[killer]> pe_ct_bloodthirst:<[ct]>
                - if <[ct]> >= <script[pe_config].data_key[blood_thirst.kill_limit]>:
                    - flag <[killer]> pe_ct_bloodthirst:!
                    - run event_personal_finish def:<[killer]>|<element[15 kill tercapai]>
            - if <[kpe]> == pe_inventory_shuffle:
                - define slots <[killer].inventory.list_contents.filter_tag[true]>
                - adjust <[killer].inventory> contents:<[slots].shuffle>
                - define ct2 <[killer].flag[pe_ct_shuffle]||0>
                - define ct2 <[ct2].add[1]>
                - flag <[killer]> pe_ct_shuffle:<[ct2]>
                - if <[ct2]> >= <script[pe_config].data_key[inventory_shuffle.kill_limit]>:
                    - flag <[killer]> pe_ct_shuffle:!
                    - run event_personal_finish def:<[killer]>|<element[10 kill tercapai]>
        - if <context.entity.entity_type> == cave_spider && <context.entity.has_flag[pe_arachno_target]>:
            - define owner <server.match_player[<context.entity.flag[pe_arachno_target]>]||null>
            - if <[owner]> != null:
                - define cts <[owner].flag[pe_ct_spider]||0>
                - define cts <[cts].add[1]>
                - flag <[owner]> pe_ct_spider:<[cts]>
                - if <[cts]> >= <script[pe_config].data_key[arachnophobia.spider_limit]>:
                    - flag <[owner]> pe_ct_spider:!
                    - run event_personal_finish def:<[owner]>|<element[8 cave spider tercapai]>

        on player fishes while caught_fish:
        - if <player.flag[active_personal_event]||none> != pe_celestial_fishing:
            - stop
        - define ct <player.flag[pe_ct_fishing]||0>
        - define ct <[ct].add[1]>
        - flag <player> pe_ct_fishing:<[ct]>
        - if <util.random.int[1].to[100]> <= <script[pe_config].data_key[celestial_fishing.treasure_chance]>:
            - determine caught:<list[enchanted_golden_apple|enchanted_book].random>
        - if <[ct]> >= <script[pe_config].data_key[celestial_fishing.catch_limit]>:
            - flag <player> pe_ct_fishing:!
            - run event_personal_finish def:<player>|<element[10 tangkapan tercapai]>

        on player damages entity:
        - define pe <player.flag[active_personal_event]||none>
        - if <context.was_critical||false> && <[pe]> == pe_lightning_striker:
            - strike <context.entity.location> no_damage
            - define ct <player.flag[pe_ct_crit]||0>
            - define ct <[ct].add[1]>
            - flag <player> pe_ct_crit:<[ct]>
            - if <[ct]> >= <script[pe_config].data_key[lightning_striker.crit_limit]>:
                - flag <player> pe_ct_crit:!
                - run event_personal_finish def:<player>|<element[10 critical hit tercapai]>
        - if <[pe]> == pe_swapper_punch:
            - define a <player.location>
            - define b <context.entity.location>
            - teleport <player> <[b]>
            - teleport <context.entity> <[a]>
            - define ctw <player.flag[pe_ct_swap]||0>
            - define ctw <[ctw].add[1]>
            - flag <player> pe_ct_swap:<[ctw]>
            - if <[ctw]> >= <script[pe_config].data_key[swapper_punch.swap_limit]>:
                - flag <player> pe_ct_swap:!
                - run event_personal_finish def:<player>|<element[5 kali tukar tercapai]>
        - if <[pe]> == pe_hot_potato && <context.entity.is_player||false>:
            - if <player.item_in_offhand.material.name> == tnt:
                - define target <context.entity>
                - equip <player> offhand:air
                - if <[target].has_flag[active_personal_event]>:
                    - run event_personal_finish def.p:<[target]> def.reason:"diganti Hot Potato"
                - run event_personal_finish def:<player>|<element[TNT dioper]>
                - run event_personal_assign def.p:<[target]> def.forced:pe_hot_potato def.duration:<script[pe_config].data_key[hot_potato.fuse]>
                - narrate "<&6>TNT berpindah ke <[target].name>!"

        on player item takes damage:
        - define pe <player.flag[active_personal_event]||none>
        - if <[pe]> == pe_overclock_worker && <context.item.matches[tool]>:
            - determine 0
            - stop
        - if <[pe]> == pe_fragile_equipment:
            - define extra <context.damage.mul[<script[pe_config].data_key[fragile_equipment.durability_multiplier]>]>
            - determine <[extra]>
            - if <context.item.durability> <= <[extra]>:
                - run event_personal_finish def:<player>|<element[alat hancur]>

        on player absorbs experience:
        - if <player.flag[active_personal_event]||none> != pe_soul_resonance:
            - stop
        - define mult <script[pe_config].data_key[soul_resonance.xp_multiplier]>
        - define xp <context.entity.experience||0>
        - define extra <[xp].mul[<[mult].sub[1]>].round>
        - if <[extra]> > 0:
            - experience give <[extra]>
        - if !<player.has_flag[pe_xp_level_start]>:
            - flag <player> pe_xp_level_start:<player.xp_level>
        - if <player.xp_level.sub[<player.flag[pe_xp_level_start]>]> >= <script[pe_config].data_key[soul_resonance.level_limit]>:
            - flag <player> pe_xp_level_start:!
            - run event_personal_finish def:<player>|<element[30 level tercapai]>

        after player death:
        - if <player.flag[active_personal_event]||none> == pe_kamikaze_corpse:
            - explode power:5.0 <player.location> breakblocks
            - run event_personal_finish def:<player>|<element[mati]>
        - else if <player.flag[active_personal_event]||none> == pe_glass_cannon:
            - run event_personal_finish def:<player>|<element[mati]>

        after player enters bed:
        - if <player.flag[active_personal_event]||none> == pe_paranoia_stalker:
            - run event_personal_finish def:<player>|<element[tidur]>

        after player consumes item:
        - if <player.flag[active_personal_event]||none> == pe_hunger_curse:
            - adjust <player> saturation:<player.saturation.div[2]>

        on player consumes item:
        - if <player.flag[active_personal_event]||none> != pe_chorus_diet:
            - stop
        - if <context.item> !matches chorus_fruit:
            - determine cancelled
            - adjust <player> saturation:<player.saturation.add[1]>
            - define dx <util.random.int[3].to[8].mul[<list[-1|1].random>]>
            - define dz <util.random.int[3].to[8].mul[<list[-1|1].random>]>
            - teleport <player> <player.location.add[<[dx]>,0,<[dz]>].highest.above[1]>                          