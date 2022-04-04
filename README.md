This is a [Factorio](http://www.factorio.com/) mod. It lets you keep track of
your mining sites and warns you when they're starting to run low.


## How? ##

Once the mod is installed, using it is relatively simple:

* Use the shortcut button "Resource monitor marker" to drag-select at least one
ore entity in a patch (like using a blueprint).
    * If everything went well, you should now see a blue overlay showing up on
    top of the ore(s) you clicked, and growing as YARM finds their neighbours,
    and their neighbours, until the entire ore patch has been scanned.
    * After the scan, you have 2 seconds to select another ore of the same kind,
    which will be added to the same site.
        * If you tap the ground instead, you will cancel the site.
        * If you tap a different kind of ore instead, you will instantly create
        the site and start a new one on the other ore.
    * Upon the expiry of those 2 seconds, the site will be created and a
    message will be shown informing you of its name and the amount of ore found
    in it.
        * Sites can be renamed at any time! The default name is just a
        suggestion.

By default, YARM shows only sites that are about to expire (i.e., less than 10%
of their initial amount remaining). There are buttons available to change the
filter to either "no sites" (which never shows any sites at all!) or "all
sites" (which never hides them).

Each site has some buttons associated with it:

* The 'ab|' button allows you to rename the site. This can be useful to prevent
auto-naming from overwriting one of your sites with another.
    * Note: Names may not be longer than 50 characters!
* The 'eye' button opens the map to the center of the ore, and zooms to world
if there is radar coverage.
* The 'X' button allows you to delete the site. When first clicked, it turns
red; click it again within 2 seconds to confirm deletion, or leave it alone to
cancel it.
* The '+' button allows you to expand an existing site. Click the '+' for the
site you want to expand, then use the marker tool to select the new ore site
you want to add to the existing monitor. Sites are not renamed by this process.
    * NB: For ease of use, the '+' button also activates the resource
    monitoring marker shortcut.
    * Pressing the '+' while it's red (which indicates addition in progress)
    will finish the adding process (and update the site, if it's changed).
    * While expanding a site, a blue overlay (identical to the one used when
    creating the site in the first place) will highlight the ores that comprise
    the site currently. For performance reasons, the overlay appears gradually
    rather than all at once.

Sites are bound to forces (i.e., teams), so any sites you add will be visible
to your teammates.

Endless resources (by default, oil, but mods exist for others) are supported;
the percentage full is therein calculated based on how much more than the
minimum amount is present in the ore entities. This is minimally informative,
and time to depletion is probably going to be quite wrong, but it's the best we
can do with what we have.


## Many thanks for ##

* The major effort by drs9999 to create
[the original Resource Monitor](http://www.factorioforums.com/forum/viewtopic.php?f=86&t=2855).
* The similarly-major efforts of jorgenRe and @L0771 to create
[the 0.12 unofficial update](http://www.factorioforums.com/forum/viewtopic.php?f=120&t=13809).
* Excellent suggestions for new behaviour from @cpw, @KaneHart, and several
members of the #factorio IRC on espernet.
* Continuous Integration by CircleCI:
[![Circle CI](https://circleci.com/gh/narc0tiq/YARM.svg?style=svg)](https://circleci.com/gh/narc0tiq/YARM)
* Graphics by Meppi on the Factorio forums: <https://forums.factorio.com/viewtopic.php?p=146209#p146209>
* Major performance enhancements by @Afforess
* Updating assistance by @Bisa
* External interface additions by @Choumiko and @afex
* The Russian translation by RikkiLook
* The Hebrew translation by JoCKeR-IL
* German translation by luma88
* Configuration assistance by @Martok88
* Italian translation by futuroattore86
* Chinese translation by @71e6fd52 and @muink
* Japanese translation by @shelaf
* More updating assistance by @kylewill0725
* Other-mod-friendly patches by @JonasJurczok
* Resource monitor shortcut graphics by @npc-strider (aka morley376)
* Sorting implementation by @okradonkey
* [The Factorio Discord](https://discord.gg/5N4pQPF), especially Factorio devs helping in #mod-making (especially @Bilka, @Klonan, @Rseding91)
* Smoothed ore-per-minute calculation by @wchristian
* Alphabetical site sorting by @mgkr
* Multiple changes and fixes by @perobertson
* [GVV](https://mods.factorio.com/mod/gvv) compatibility by @JasonLandbridge
* Space Exploration compatibility patch by @ExterminatorX99
* Estimate calculations by @Kingdud (with apologies for taking over a year to test)


## Remote interface ##

YARM's remote interface is grown as needed; there are only a few functions currently:

- `remote.call("YARM", "reset_player", player_name_or_index)`: sets the target player's character to be whatever the player has selected (if it's of a compatible type, of course) and clears out internal data relative to the player.
- `remote.call("YARM", "reset_ui", player_name_or_index)`: destroys the target player's YARM UI, forcing it to be recreated (hopefully correctly) at the next UI update cycle (about every 5 seconds).
- `remote.call("YARM", "set_filter", player_name_or_index, new_filter)`: provides programmatic hooks to change the active filter. The filter value may be 'none', 'warnings', or 'all' -- other values are unsupported. The previously active filter is returned.
- `remote.call("YARM", "get_on_site_updated_event_id")`: returns the identifier for the `on_site_updated` event, detailed below. You should probably call this every time mods are initialized, as it is set in the main `control.lua` runtime.

Additionally, there is one event:

- `on_site_updated` is periodically raised whenever a site's ore count and stats are brought up to date. The event contains:
    - `force_name`, the name of the force owning this site
    - `site_name`, the name of the site that just finished updating; site names are unique within a force
    - `amount`, the number of ore units remaining in the site
    - `ore_per_minute`, the number of ore units mined in a minute on this site, based on the number mined since the last update
    - `remaining_permille`, the ratio of ore remaining versus the initial amount from when the site was created
        - permille is analogous to percent, but multiplied by 1000 instead of 100; its symbol is ‰
    - `ore_type`, the entity.name of the resource entities tracked in this site (e.g., `crude-oil` or `iron-ore`)


## License ##

The source of **YARM** is Copyright 2015 Octav "narc" Sandulescu. It
is licensed under the [MIT license][mit], available in this package in the file
[LICENSE.md](LICENSE.md).

Some of the graphics (the eye icon and the gear icon) are licensed
[CC-BY-SA Unported 3.0][CC-BY-SA-3],
and based on the creations of
[User:MGalloway (WMF)](https://commons.wikimedia.org/wiki/User:MGalloway_%28WMF%29).


[mit]: http://opensource.org/licenses/mit-license.html
[CC-BY-SA-3]: https://creativecommons.org/licenses/by-sa/3.0/deed.en

## Statistics ##

19 alternative name suggestions were offered for the "YA" part of the name "YARM", among them:

- Yet Another Resource Monitor (narc)
- Your Awesome Resource Monitor (Keyboardhack)
- Young Adolescent Resource Monitor (Kane\_Hart)
- Yiddish-Approved Resource Monitor (narc)
- Yawning Angel, Resource Monitor (Tivec)
- Yeti Approves [of] Resource Monitor (Keyboardhack)
- Your Aunt's Resource Monitor (HanziQ & Tivec) [it's not your grandmother's resource monitor, that's for sure! -- ed.]
- Your Adorable Resource Monitor (Keyboardhack)
- Yassir Arafat Resource Monitor (HanziQ)
- Yawn, Another Resource Monitor (AnarConn)
- Yum Anal Resource Monitor (AnarConn)
- Yellow Arrow Resource Monitor (JoCKeR-iL)
- Y Another Resource Monitor? (AnarConn)
- Yad Avraham Resource Monitor (JoCKeR-iL)
- Yatssi Atssi Resource Monitor (JoCKeR-iL)
- Yahoo! Answers Resource Monitor (HanziQ)
- Yes! Amen! Resource Monitor! (Tivec)
- Yallah Ahmed Resource Monitor (Tivec)
- You Are (the) Resource Monitor (narc)
- YARRRResource Monitor (mk-fg)
