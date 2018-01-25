This is a [Factorio](http://www.factorio.com/) mod. It lets you keep track of
your mining sites and warns you when they're starting to run low.


## How? ##

Once the mod is installed, using it is relatively simple:

* First, you must research the technology "Resource Monitoring". This enables
you to...
* Then, craft yourself a resource monitor. You should only ever need one, as it
does not get consumed.
* Walk over within build distance of an ore patch, take the resource monitor in
your hand, and tap it on the ore (click as if to place it).
    * If everything went well, you should now see a blue overlay showing up on
    top of the ore you clicked, and growing as YARM finds its neighbours, and
    their neighbours, until the entire ore patch has been scanned.
    * After the scan, you have 10 seconds to tap another ore of the same kind,
    which will be added to the same site. This is currently the only way to add
    disconnected ore patches to a single site.
        * If you tap the ground instead, you will cancel the site.
        * If you tap a different kind of ore instead, you will instantly create
        the site and start a new one on the other ore.
    * Upon the expiry of those 10 seconds, the site will be created and a
    message will be shown informing you of its name and the amount of ore found
    in it.

By default, YARM shows only sites that are about to expire (i.e., less than 10%
of their initial amount remaining). Clicking the single button shown in the
YARM interface switches it to "all sites" mode, where it will show every site
you've recorded.

Each site has some buttons associated with it:

* The 'eye' button allows you to remote-view the site from wherever you are in
the world. Click it again to return to your body.
    * Note: it is possible (though unlikely) to get stuck in the remote viewer,
    especially if entering it from a non-player entity (e.g., while using the
    Fat Controller to view a train). This should normally be prevented, but if
    somehow you end up in that state, you will need to find your character
    entity, highlight it, and use the console command `/c remote.call("YARM",
    "reset_player", game.player.name)`.
* The 'X' button (only shown while not viewing the site) allows you to delete
the site. When first clicked, it turns red; click it again within 10 seconds to
confirm deletion, or leave it alone to cancel it.
* The 'ab|' button (only shown while remote viewing the site) allows you to
rename the site. This can be useful to prevent auto-naming from overwriting one
of your sites with another.
* The '+' button (only shown while not viewing the site) allows you to expand
an existing site. Simply click the '+' for the site you want to expand, then
smack the resource monitor on the new ore site you want to add to the existing
monitor. Sites are not renamed by this process.
    * NB: To prevent inconvenience, the '+' button will also drag a resource
    monitor into your cursor, if you don't already have it there.
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
* The Russian translation by RikkiLook
* Major performance enhancements by @Afforess
* The Hebrew translation by JoCKeR-IL
* Updating assistance by @Bisa
* Graphics by Meppi on the Factorio forums: <https://forums.factorio.com/viewtopic.php?p=146209#p146209>
* German translation by luma88
* Configuration assistance by @Martok88
* Italian translation by futuroattore86


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
