ThreadUpdater =
  init: ->
    return if g.VIEW isnt 'thread' or !Conf['Thread Updater']
    @enabled = true

    # Chromium won't play audio created in an inactive tab until the tab has been focused, so set it up now.
    # XXX Sometimes the loading stalls in Firefox, esp. when opening in private browsing window followed by normal window.
    # Don't let it keep the loading icon on indefinitely.
    @audio = $.el 'audio'
    @audio.src = @beep unless $.engine is 'gecko'

    if Conf['Updater and Stats in Header']
      @dialog = sc = $.el 'span',
        id:        'updater'
      $.extend sc, `<%= html('<span id="update-status" class="empty"></span><span id="update-timer" class="empty" title="Update now"></span>') %>`
      Header.addShortcut 'updater', sc, 100
    else
      @dialog = sc = UI.dialog 'updater',
        `<%= html('<div class="move"></div><span id="update-status" class="empty"></span><span id="update-timer" class="empty" title="Update now"></span>') %>`
      $.addClass doc, 'float'
      $.ready ->
        $.add d.body, sc

    @checkPostCount = 0

    @timer  = $ '#update-timer', sc
    @status = $ '#update-status', sc

    $.on @timer,  'click', @update
    $.on @status, 'click', @update

    updateLink = $.el 'span',
      className: 'brackets-wrap updatelink'
    $.extend updateLink, `<%= html('<a href="javascript:;">Update</a>') %>`
    Main.ready ->
      ($.add navLinksBot, [$.tn(' '), updateLink] if (navLinksBot = $ '.navLinksBot'))
    $.on updateLink.firstElementChild, 'click', @update

    subEntries = []
    for name, conf of Config.updater.checkbox
      el = UI.checkbox name, name
      el.title = conf[1]
      input = el.firstElementChild
      $.on input, 'change', $.cb.checked
      if input.name is 'Scroll BG'
        $.on input, 'change', @cb.scrollBG
        @cb.scrollBG()
      else if input.name is 'Auto Update'
        $.on input, 'change', @setInterval
      subEntries.push el: el

    @settings = $.el 'span',
      `<%= html('<a href="javascript:;">Interval</a>') %>`

    $.on @settings, 'click', @intervalShortcut

    subEntries.push el: @settings

    Header.menu.addEntry @entry =
      el: $.el 'span',
        textContent: 'Updater'
      order: 110
      subEntries: subEntries

    Callbacks.Thread.push
      name: 'Thread Updater'
      cb:   @node
  
  node: ->
    ThreadUpdater.thread       = @
    ThreadUpdater.root         = @nodes.root
    ThreadUpdater.outdateCount = 0

    # We must keep track of our own list of live posts/files
    # to provide an accurate deletedPosts/deletedFiles on update
    # as posts may be `kill`ed elsewhere.
    ThreadUpdater.postIDs = []
    ThreadUpdater.fileIDs = []
    @posts.forEach (post) ->
      ThreadUpdater.postIDs.push post.ID
      (ThreadUpdater.fileIDs.push post.ID if post.file)

    ThreadUpdater.cb.interval.call $.el 'input', value: Conf['Interval']

    $.on d,      'QRPostSuccessful', ThreadUpdater.cb.checkpost
    $.on d,      'visibilitychange', ThreadUpdater.cb.visibility

    ThreadUpdater.setInterval()
  ###
  https://files.catbox.moe/om3tcw.webm
  ###
  beep: 'data:audio/ogg;base64,T2dnUwACAAAAAAAAAAC320z0AAAAABL/h80BE09wdXNIZWFkAQI4AYC7AAAAAABPZ2dTAAAAAAAAAAAAALfbTPQBAAAAXJIxuwE2T3B1c1RhZ3MNAAAATGF2ZjU5LjI0LjEwMAEAAAAVAAAAZW5jb2Rlcj1MYXZmNTkuMjQuMTAwT2dnUwAEkG8AAAAAAAC320z0AgAAABemGu89/1f/vP//SP89/zH/KP8x/zj/Sf9S/03/W/9d/17/af9v//8j/2v/W/9c/1D/RP8//zf//2j/Jf8f/yP/IfzQ2b/vxhKXDvAd38yNNR/YuQzLZoRekukRCo8ELKGkjtWvEoB7igEoh01sgM6acgaaWFPpDtGE/R29/pkcyImVV8J1qb4SzqQ6URiVQhfV8Ql9F+TBe1OeLwAuJQ3jojlnlew16we/RcyNYzKsr7UrNcML5qUfld3/l3MxxkpZHWrEmixCQmUR/5Afhh3x3PO6lvUMyOifd7y0nsz/48vAtNpPCOxIKfksxAlRcQCPl+C9HB5dhPWWnSZX1ttDh6ehaOEgG7vObp6a5EtbV6aSUcwwbi341LPT9hGIywjjePd4ctc93vEcJ9REx7ZTRQqJ0ir942OdMZjKkYSo8IXSFt0INoqnytpq/Y5THsoOc3G3KX8F2oFH5d0pvqfiEmwdmgDqn6+8eTFbvUq1hO/XjIPAiv7Pv3jqhqvi66Z8a+zX9RDS1SnbvnPBgVhcGqV+kzvWJfzU77OF1g7RQbM+BkHETdddO+TvJhZ0AtJ2ftvOD8vD5HgaE/+NJtqoNdxmXSShQqGZkR73WAfYqOj7QpTpEKlwdONls+qX2gVmISUTXj5CMyYRCLbOAjamL3VGx2V5ackp265qS2EjyycgWAuPWhF4nDxuEpEiyqGkYArMdc9N6soSRaC3ZMsfGbv6AGdxnjALBESbseLPUPcj/u2o9eSX6h4ePUSj0YIpGDDlV/AvO0cgD7ggrBI6FWmWvDBnEqXcYzGgU/M77/i1DrezG/rITCl0ia+XDciZfLPhi90jjJ6QcUzg7xtjYHjTwuc7NFV46vXIwSbxSbKS2pwJKHz7bvWwrnO39WRF0qzkwQQOON1s1A9jwgt6MCvf91fsrxx06ABYh0dtZZbFZGTaJXN9KQRWyteLcaZYo9HKhaOIjSq1/OHgvI9H9g6BYpw8XL418S2IDpJ6I2kS1cSV6QAm5c1M0hS09dFnQki5jI3uOPO8301AQDw9YhgCf0UFCie4fjRilAFBO7j8XUQXJFsGkZDxY/N4mNoiBszqo0ESpewTqtylCZT/jVwHrY2wJLWCLiHDBlcdFVYl/HcXf2DoGODSSC5L2D4JPTUJkNEeGR6mE3IMR4ZyOp9u6Lq5hxVo3sGn+fof7yWoRzod/gLSpVkBb4fSrkbrdXrW2zIUqcYGxCx/YTZSc+wqzd3+wZMD1i/4ee12ni/ajP/avMSXVtRTvxRo2KVOJWETlM3Regm0HvVWvy+N5H1xHaRDIxigBD9xx2mKR3XSLpiOY7GPmFc4mV9Y+U+yaH2jKV37cUAlwrREvn3rreiVqeoYiE2ZKsub4nleVU5s69JAf+EQBz8TwGDUH2FF7/+9MVzbMg5+eVfD2xNHX34HndJ2KEv7pk14Bqe6BwRbyGR5eMQ9HmZDZmAOAj7RjRLp8suHZAAAAAGX7vVjzObVgyyx+jG3sQADDS/vzQAAeAACsitHmqvnyYeUC677iSB9krOVbCuuebKS3Sg5BErjfAGaGFlhIC2/rNnmF8dDqCEoGoJdNZkTpBZH8p7JF8ZMJ7CiuiM9u/RUeNBC4uH+e8AOuEYOlU+UxPd+vxUw3pT2ICL3epWqQ0aFJj2E4UoqN6xKfAXZwFDURJs6CsDNmCIWUJoiH0/D5eZ0LWK1dWREnDwCfAVmck93N0TKc/q6pRVn4dj8461PsJRTXg6JfRUBigi8+MxbxHqboKd+GbMuo4kQfara2IIDPe0OBzOrzKeByXogUObPoEFFpKgMB+xhbq2eSzwNmfaXvz9VEZlGj9NqEZFqKK+OGdT0MA0zkA7j0Ws/X03REHqeftXTYRpGntd2R0jTAAaPtEwBoTnd43qS/DIuo6Tt4SST5ht2Lf+0dNZX7oaY6ZX0b+kPPXEdHSzaOqnpr4fH7p1P8HSwAje7fkWJ8SaY+l/+V6pKpFW3QFvp6fRNuPBWyH+U33GMpGlqfGzHEbMMxT1GrM58CiBCVGWtuePB1re4YhVws3fuNUYVaep+65VSOvwuvEbtuz56M7ChavcyiN9Dc/5kbLF/ice1wM5qcKfZT+T1RCzK7cLtQI5gKOcpHHNrmioXDhuvkI0x1YTgSDSf6LjF/zL/Do1V2VUoVdHpi65tDDlxNueYTHvnq/aUUpcOa756EXaXOcCRZJJ6GxhYPd3mEEEamEBxOVtCpbMO5muCbp00K9DGpI43KaA6WCC9rlxWA+hWFq6Gtl+/TkBakIT1cgqlXKxymYVyQLourJ8tvOijQZAG5eG4ELKM0ZZY5fwuPUgdV2StnAblRYc0rQQisIrK+FwZFwMjXVPp0tkEVxcMpNIj750pfKCourrKrHz0fyOX9lqtUEAYt1//zcr/nQ6c0v9uh3Yeotg6b0WiA9BcjPIy4Ab7F/pmR09IboYkIosJvTe9jqGHsh2O4O4vx7oqvX1zK+NuTCBPyrNAlBo2qE1ocYrF8wAMMzxiCxDjaEFXX2EW01CGInn2EWpjRe3A/G+ojfvqBPZq3/p9UU7GtcjCsvB39O9Wwy4qi1dRVLcx2DYcB1fP/VjoIDeRhFtiP0jHzP1ymdeeXji3gGvb7xL5vFy9T+zQuMq0lxeMVrKZs/09uq0Ds4V/MidJFR3eXM7ST9f1k4FT/m9cKKZTtEtytHDSQXxpaMLRqxzKgE7DhLYmzYqlo9pHfar8MFwKoWbLMw6MEC7MWvO5MJTNMxeZaBuGG8rnEnxdjXFoQL43RYvJdiiAnjx4ybu7ScgaOjjs1pa0uScPWVjS+X8nHi4xjW2UwFe0N9X5ItLIxJJGpU+3RHI0dYZ5vMHHtojwq7sCq5xF6peAWqwN7czs0jsvXfJ4VxD+Tg37ltBp09800fzECzx1NAc2bPaLVa7r42XpNmJc/8q/u/pOFExMSUW5m8ojrLLzG0uWZAul0iImDwHIK67V9xZgSb3dKn5ej7Lr8hBVmoc4zYMJjOAUV3eAdSaa3e0plyHpNR/hREoWJSC0HOXd6WGifsdUSd2eLTW4rQKUpKVlcRWDmds0rkqdV0IIeHZZTJT7Ki+Slcgbyd64k0GksOCf05LbdttdoyXB/Dbwe/cAH92C3vYCtKY0iNC6LEgrggCbnfLRk0zeHtJe4TkHS4SetfJkWaKJpolTvEHQ+NXB7Iyu7c2UXh/DZpZbi+MRB6dfjR8b0GNr9Sg3H2Fkfr3oBXHm9DMrOpWlelVmL8AA9UPCyEFpqieLQLs66oDpiOrLx9bBUGSeeon3lCGe8+Izbl9AB9hQK1n0wYNIS9iv2sWqL7FHJPFOtoWrwjevY6j09c10hUyi/VMVWO3AoLhvyqSiNNBZuVxpqwD0Rulc/hklI2QzZs67C+XLoxGfOMxZqIL4eX6J2bAOgLhVyLvz6Oubg+5kOo7NCbVI0ulT8ZqwiKzIi52nIDYSkIE2EE7pYyMH+NHQdThcqMQMEypmHV099lc2e6L0YokCST4nYCS56xL6ZuDtD/y8o7eZyp3EZYYjgxE1av3dcwkxZKK9LTsGbJ8KFtKMSh6SBnhirVMJP765K5HyW1EZM7JuSxeUcMScDmyck0Jxh/Nr2+xNnoDZ8/F1BPiyFi9kBxTNcj/qocvb+MU6vvKjl4TfmaDEc5/vn9mgzDMceA22kDzc83dODc/X5hatXXp0xHp2MZNZbhh3dG8rKnhooafbUtUG38FjigEKIwgBqVjq7hJubrIzUh7VuJ5koBGuXHzu/RfN0ZTHgUo+bokdXIzGU6Xl7T9nhA/V9Wc7ZFsBg8AmT7EwyqAaoYzafPMXL5OICHMuBGNl6sWYr1nbiElR065g+yfRx1RltUUgOoWg1TKG9+0tKQadgXP1bHhwOvYTNzpwf/q9lyL+SKO57Aw/Etw3Jb7/+23aM8Xa9P/4miZ4/DAehFAv7Qe8xyiiYHW+W+mlpE+RlwHMXC1qDca99G6C0tCaeI4g5qj3iVcNcgsP9EoyAFvFXgZJ6qT30MCaoIZkhYuOK4sZkI/fl8TrehY7tqUgL864zWkrplgHG+3m0FfCxHUiX/qvrfrlSUoZKhk1+oRcy+LcjDZtNEr8QX+I0cqpCFzM4pdT4p3IWANSr+UGiJjxL6LWaF8bXSgw2CPFMl+jQQuyOnrU73TOZPLEs5xQ1BlXUQWpJ/r2T4q5+hH5KjzTZkofFhHp9SVDlUO/VPIH8azeakNJXXc/kKDY48S1UcBa3fVgBZX8zFfmjyaPGOt/qtuVbxaLNWsN3LFYsfQLLKg+9GUb21fxHnYgxZC+jv+3K1z5eLtHKU0s2f6hU4skinazm0CeOuhwggGs9BGJ6HtArpLCnALZCZa0E3CI0E71m/y8sGdj9m41vxDN0HpgYCqjUlE4xgmBQQIgecFj9lU8b+sWEcbLH9ov+KQ8FsYUSAUpCo2WPTciOeu6x26Yjk9CihM+jTc/+tGVgr6jyVtyeVjqs4oa5EaZZE0e4Z94Xq5nEM4tgr3w//dncN75Of9j/qztPmM+4QRbomNWCoY5yo5+2Nw4UkUbsYs8EOCgcJHZcR/822jvghErQIsshIYovXBwIryC94tjIF+P22h1tg/xk0IBcRKnePoEU4OQKG2qoS3xyGhw+iWGLE3zEup2e3u/I+uYGn3OZL7nrgBIeZDBQDMvQKGgTRlTc6PhbT3aFBE5AkxWVqVExKTDfcMXVdKTrRgbH2+Wy7moM8pVv9r3bAljrpwBR000CWFXeXvi3uWYwFHHPSbEPGmAQYMwHT+XJchc47JG0gdcmVhpwE3SNW2//oktxgxPmZVdNr38vJc8k9B3wjeHlrd2oZq9ZaTMZUESGYl5bwV6KUajRD2wReHi124CHyEPCZr2Oo8tMPIZyIeTUYtT/hRhu42Ln6s80fsrLcTt43DaZgA5k46uH98KRwd05yT6TVZxQUDrz9kIFxfSFiyzZEJHivUQM2+88He+TlQC6l0+ShKQanxs46u5IsJYWmCxBh0JyB0I1hAAAACxYSIMExdmayaqCIy36a0XtYqRxWmPUIM0s5kUhfs9bT4mO7E/jFU9OhQkuG5V3boAsLiBCASgF0eotdeiSmC7we0nC04m4Lx0yB5/XbT3bKYtYdOns5PyEZcyOPysIIoaCILcPGcbLpGHzsTxIu6PvItIt7O10o1qpNVoM9B7fn72EFvXCPiJf/m5vPb9Nh+QPq++za6mic6UhloOBrFU3hU+pnnG5b/dbJJbU+DqasoJMfK2tvy8mBI5Ju4zHhKNSlXHCiusFWbWDUYedy90AEFzhE2OvsqpTXFwOHHwjtrSWT7SvGW3O8bRenxEL1VFdP59tdAnlUSjYOuZ2Tdme9Kyz47BuvJYUbeirpFe5cBnqDnY6E34UL9M05Jqp68nLa3gncAaTXNCjGe5v59wNRWJs5z5TvWtEBs1qd8PUb7SGCk7s0JYMb9PmoFMMLs/tEWt0DBOt8R9noiQiek4JZRJIit3dzsSGcAb9gftatBJsfdOn+o0RGVHIwbJhx9RyWYTIqEPLDwcrocYm1WqZAMug668sbamxC/wmfQiy3zX0Smsb7sNw0mPM0xuhEqkRtgvrAdMFxsw980xpORA+cqt1TqbQdIU6Wr1nLPuV9gciI/VrDYXgoWVbbd9kKoLRsv8YxHL9IB3WeBVmXbpsT1TBhp/3Ft90/WZoFvrkhjw2z/b+bPeRz6TOYbMNL/8MKz0oRtE3jyHA+3jsyotLk2hPnsWwjzuV409vnEZyDkaY06oKEljpwjIn6jmPd2Thyo4fnXPApS7+ZehsszE7cfuo0s7a1/ZJ297jPTa8E32CzBxT2BPabz31ORWhZYu/asiVzRTkfUHzX885P+X7Cc/qVkkvpNPpTvTxDnrRT/Jz1ibZUwziff+QQ32K6dYqfXKBCw7h1Z3hfYmaJHLG7Q88mjrpkhF39oCzXGCx8a+LhkWfEVFQ2Pzb0MqZg9Xai0yrwWZUPM/c/SH5rUp6yA0WyGD6gpE9dvARUe1cqKThKlDQzIeiDyG162ETELy368l7LB5VSxNQrTHetzecYGK9ves0X6PqRkjO57zTvqnAcuztdub8jNpwT/ogB1n0Oqo5lqj+4Q3/9rGqLrBYa+JDL1CA/eoEXKnVw5RUx129koUfQPCzVjyTSbwwt+kcQGnMKaz0LcHq638vJopC3e2sNjjfe76T4JeFsgfnbF2adNZbLGf010wLJSIV1kXNe/wyqp/7GwUSICVXKrPAQ56uGc3RXpiGgKfr7Z8WTiOvhGlTsSGtY9wUxHgRIoSDZe4F6Pk9zScLY0JYwJu5fY6rxqfp9unSNhj3SCH8Bl18X5Lg4/IAue56+YRI63WhSPL+SGluKK9RGMi5gr4AFFhAzQYJ3B4cvq5o7wiXf8rEjiHZhkn0rNNQ2p2V4/tau6oA7LqLLic/633Va9hq07KrjA9EXHQgetAYjlDNdjKHljthpyu52rk6OWZXhQSCQ1Whq3FF1DWr4v/CFj2hMsWDcmn2sWhAf25uQ3pn3oxR/YC9QSbq59V6PpjVavBDy4v49tjl6lEgqdQJ+fSpZnNuVZJtDlwpKwO+Zxyyl+RubSA6bdiy/SDc/EwWg2k2EFi7n5tElNx6ut2Ix6a/jXDPlj1UJL7/LzAnKJ2ZbI+lPKWGME6D5kvMlyC+5+3D7nbHoS1KuG9ZFcGXRVzchuzWUFPzGmTv/V9UcAIiJuD3PsXxQqaVqaX6HSDY8pOIBJYS86119xdCZEqumq974mBn946sicv/U2giWVjc+Lt8YoXhtJq/all3Ira24KHC/lLkwJVWh5yTYiDnDKbpSw8oyHWc7kOKlqqev+E38QT8B7e6zd4zI8oWR425EZyCpVk+IvaAh+GWfrkIE8bpDDIAIdswdKl2pFK8E61hFAVUd1rlIxL9ixPhB1Wa0++YiMmHO4mb/bxZHfPfsYjAtlFKXg88Plzofh6+vLpsEc0cISU/ORvBerRCz8/kayXadsYnuM6BqeRJ0rVNg9fTIwHlKKhxGt+5B6Z2GyjF9ZYl/aOFNGuziUOdByEd+HR4GqGcMGG63BYExklu99MGDOLoYPckI48T4dIHPtxUG9pEZ0jb0AArS7/CqlV6u77/Lysr6MEjINWZKuWUtQuGfYq37bDjg1MGWqfhKN4k3itxYkzaslEYVnfWBEY441ZIIcM7Ew8ll6kIXjzZ2M4RLIQlkJ5G3N/gtCqkqo1gnIpYf/o+K3pzBmkQa9MQq3U/KS2Z7EzLtov090guc0U5oenHVMK4mvLCdAVPou3lVMlh6gLRaH+++0MzkEyNWJa6hZ5NUKqOHsqT47t6AAN7igAAile6XwHkPReFlw6uPKasyZ2rC7g4GoyQtj4rrw4xMioOR5L137oOogAIjiOhxV8J8inTDQ6UbiFFqdNNlIPNaApfHmQVSu3w0cJc98/4m8s7PKdF+DrfVd0BTWrR6PXih7jtqlQPp7wA/l/ggTK6uTGCdn3wrDWXiSUNP7WOe9Ty+4lOHuMcI04X2YpbQfUbNpKzas0l4QkarSxd+AgYrWTBSsdXXG1HE/JP4sBiImMRqgy2oRSxo2I8Pj1Plirt3KLeMgEaAJYS1T7/L/J57BYetVM5ghSO500HsC6mmivHSIVoFZ0tybHih9z5ljDTszk0qXidvYB+rdKplRWxFmBFdvh1rSsvhR7MissXDDsh9lF7WdFxE80zx+4IfZ69lTiEquEW7cf/It3c1WVsXfNWWQnlTn5xew0HG8ODPJbA7/Q0HuzsNW9LK2oIjwr7oJw8ER14K5rUXOUmKMCRqBtHP8cOcgFh9s2QM7yp92z2y/SnIWDxSC3LYbwQayoOj12zG3IFJx+rUbR+ISui8Wj8Nta+RrE8Vt50tBN8LkWE5dm0KUFDlQ/0hfTibizjLRj6PPCbZnCQEOcGCDIsoUZd512O9tImy5y9tzOn68c7e5tgpBbQE0lfqAsYphdqVwfpWwsY7qnpDkiB/EiX1wNv9GN7T3ZHaCEIkMy0HXiIISuGRv5FkFljx8NmWm+ReclCLjDBxZtBUP9dfAcqKnrUFCn9d/6gXgTv+jT3KLrauaPY/Jlg8kViGmjGdxv7mHeOciMkRwzuJFB6AbitJiTRRA9lRshTHVXEiJ3BRGmFirSygTw46mes0LpcjexppY/lCDLo1ms5DsfTBmn/aofXDhJ0tk7T7xwmq+99Q4HUqWIb1D+tpH8RYJjEhWs/gELshkINiw1tF+ru7KdqvFbW0BH3TNQvhS0C0SVul/KxpzDEo+cEssUdOjx/OcK5tN3MGnx0F7QzE4Dbb87jjn+uOjMnjMQV07ESPv8uq3moda06cFpl/8A+dISUgy1CEqRigCfoeEhGphW/m8+XPP7DMy0sPzyyuluqicSDWSPzSUKwM6lI7sDT9aq+513V1QjFYfcC6n2bTsgyatPL29RcgSlyPoZ5t2VcmOEfWpgZ6Yu+Rs/MRWV/ywa5nHLAuB/kCqRtLUlR6d0x0Z/vojJQ9Y18kEtbwzpShy0evDvcrTUc9gAA9MTAAAAAAAAhCJ+2HbMr0C9+xyOrXOG4GsuQRZd6mABrNpot8As468ICP9BNmW6yT1FChnYEbSmHUrNJ92vzdM20aZ8HbLZ7tPqmKIzaD+42XV9uQk0tbsozYHFjHRjlOk7RQImNSs/hUoJtoX9SuSXt0sk+hfeDIdlBrkVwoGfte/N88yD6s1Hbqd3IR3hP4EH1jeYBVa8qjYAN8p3QKtczGxWQypz0PXBWhnGuESDAyvvjhOvpdJaj8p86gdI9dafWbqXRaSaR5OY771a+/wt8yNkSVH1bxNvE3sVhu1ksQbwDdhiNNwOz+1YsO+L2QNIHK/gt4OwbuyyDoc0JpojEJoV2gs6CPSvPxWDfRaTa7Q0xfH0nIW1xJSP3v/rLcKE8U4b9pihE1mIXToJ+bUIqLUjnrE6zsVgC7NCjkpcaTNaom9DCwws/dTObkewye2cQaqAVg5AzjZi0/zwMpGaK568BbEr4PZOEOa+w5hd2H7/30BGqkZvIUvaLtxNMl6INMq6XJ44Oo/p1axWkSaSqNDGvVZ8+oz4fkEDAS78yI7i6JOWbVwlYvaZ7XyPfZVdyWcmhhuN/LljSJo7CqHSpmPpLybmkExQHJOvwMyfST0F95GCc2eI91bDyLC6GLpr4mxuy/D1Tn4VCfkUsyetK6W8PONo+ecukehsLzWVoeCJN/ZsGD00XXf3UTlJby3/z9Pt8Zfw74oQjLk3uYKZGJiKro1pQtv8/KjO3s3Vw5122pvpLTPTL3iYPsG280S79ORuCeO8rwU7T+1OY+g+UzEkgzo4RKFbgaKXvygSc+zljUjbsfQEkwp1ss3bVhB6FL3ugtIpau1uNonV+xfxGIL8ITcS0EaCrsHSzE6WXnr+EfmaocEd/t+414owL+qZ1aNqnaEJ3jSPNWSlvhx45svq8HekoC39MoK8Xu/5JeTU8sT34XC2MQp6aljhLCaX8lX1ymvwJR43HdY6XJnMVkS+LRKm3ygyxDhZYWBTemu7IFdnyCD0zne/TgJFPZsKYH+tg6kbED1+MSid2wvl0IjI+1xIT5oMOoAQB6UUVPpX5gQfQz0nmD/F+uZamI0KjE0bRNXbPlB4GT7v8jMYkUCJkFjWE4Cp/557NUAh0jhGwB/3ZLo5bHq84AtvKoFk6z0QWf638qPZBT6UkF+BpsOy+VbHggbMviTirWqrapyS0vz8q73/FU1sqarYFvnUsJiXVcp/3xHW6CKkkq6XZYRczcjIR11f46EvJBvIhmMbCf7oNX1qvoI0kBXyHs0J9lxfu84OGIrQ4clnWhknd8hUxTddJ+2X8sC4fXCXtToDge4xw/wdPWc5kVgzmib3BD+CDFNLlsIs1hs/r1n34kfWZVXwfzwJjoY+gHkAR7BiOmQtIDulY9DVrG8FiC2ZWWXG/3zRin6CfL8uk+hv3VLO9PHUjgph59BebY9I4KW5fQXm2PMjNWs+alZ81KrJ9TA5D6dtObhAY8yNTVAdwcT0BQddaB7FMWKOLGaengRP6ZcdbNFbu0Mg4vWbCGdPhy4lV/ZK4qbJKuYWHD0DaV9Vkes3+3Wg2ue+kdDmqqLLQpla3N1o5wNqSIofNG9vcIAUBLomyw4cbW77KlNaEcu2kSjb+BcA8Jb6r0K19ITS/PyYAt4JrsvyhOAytXstRjtDS892mhmnxvNI2uBQy2pHBut4UINksYnx8kd6h5XJZ8jMtoi8STJTLrM7oLqHj4/lLNR7n8F6he8yr2Ouf4fQTSAEtbLMXvke5eE8gio6h5mmqbm3bG7aZNSqIVh6CcXvDwIGWCXYkw70g7HBKRp6m1j98B4TtMmRyTHYBpktscnzJFvpS00ZE7kmPuO6PDcxyctbtfCcNqjC1geV7o5UIgYhZ3XP/Zkedw5o38tDpZDkqnyUJNTxGqfP9iS/DgX275h7Qx5H/YXB6QsmhSEAoE2BRY+g+a/1V+NjwfEN9z14vfPTcWqp1TcjCr2SJMCduriJsTcE17IzgVSrK7NLm9H0DljYCffovE3feROcfDF89LIJ+CfnyxrTpc6tH6naaOX1rtKu42ormlZHFOEspQX8/Ku9+0tQyCDF5AUYxFXX3CPMin6EyqA/hz5Lkiu5zddEa4/k4tro074MKJsxOZp4yhum13ItjCsr6xVXFFc16M0c+zxcJ3XRT1JUcODPH7DuX95bjjSH8sEgB/yjel8SlIPf1kcCAtwQWKfF9fjreAgUTDQoIKH6FAgmqQ1GQ7J1wfjBUPld0z2rZk+YhzgJr+fhGT4Hnnc7uRX6R1wOjnLq5LdVt9wO82UHcKeJQn/lQ0J43fLC4zcUAzyLn3Ktvc/z0T4ygWPXGEfrGF8W6yFz+tiDHScbNn82d8P3ryb5wq/gqnBeuZRun+NcpFc63tGAJed1DePwnloC2rYhwXBng8vVUrfsKj/5H6L6jWgGFx2kn34amJiylNsXJyn3H3Frp+YfJD2qy5vdPMTSdstBEhBJ2PT9IE24FPL8+qi4/w6Bapxg1D1YiwjUqNHsJnzdpfZiz/M0l/0vkgD+diPIoYaWLkQ/45bz7Bo/yjXgq8bDGqr01PIkrsuX2i+8lj8jEbOgWAY8tFFy+9OgXgAhjNMxKQhzw1vpIbxOngjhnEmI56QLMbmnjLRWjMAYB8g32e8/uXdht68qzdNFgsbt1MBZSCNa5nTj2EjnNH7VPHyOhBiB2TpELqwinFlUkfSVvsRxftGA2clfbXQZZNF3TCD0Qw6aOV6QFiFufW9e52/tcZNLbuSUUOqGUXzA/vH0erm1V6baScZEsdo/f+q5hwyZR25nJNGHuA5YDurMvtLebgmrSbvK0dtXFN8BRnKkkDxPdIQKns9FUUvrKLeYWDE1n6StBsrhuWZhBysxruw9t9QFw5E2CzMuHFaTZtUC/P+ex2hG2m472WF9oJgsPJggEO4UG3/9QCxHYTiWWve4B2H6ubAy6mP09YBJD3Xzm3xxrYbwPiBuAZsMVfVjKmkgej6oicE84yqEiuPmBhgKFkTQMmRNNjXfWsDIaI6n/PNXLxk6KlGpSJktqm+kjQDX1Qaj68tcLmGQW0ewVtcI34/C100Kw8Cfn7wIEcFEXIZX7td+8uY1QAuF67lNdNVvohMpNLfN9AV52NcKvQG8k6MQTYrdwKaqyUJyhQILBhh7Z2KE7r1Zd0o5O1lTNpnC1DrAwkjvRTPMtBJsx2oAMa8nF7n/bou3378ETxJhg/F5FvhOAASrra/t5xFPByWB/46oBWDLT+eWmg21wnRi26FYjN+pBR1TGdte3VZ+hrFlehKIvly476/hDyrsvdBnh/4HBEZ3SFgHR27zhhza1GdjONFkTAle8WKhEV1QZSiSlTjrJJX8q4JZ23brBk5i0VQsUx+DW/DDFqTOgiSyu71IdJ/JeozVSWsysKU08dK4A6M4irCqSL7e1Xzg0pf8zeUfUSnmoU7j2Y++kbEkfsWFWWboKz3ZrFySVUVSgYVuQa+MLAduQVrYzeaX+No0mghTwP/wH79RUTnq/YH69M9gGyVdXtLtLAnk2hkrhxfYKmhqfcwERWEik3bB9vYNRjCVc3GVfiPooi1t17sUARGirWJhg4MTcKuAqC+SbgWcqKLSts38xMa9dYkJo9y5HbiyPf8qJADW7CDrRUE6Vo5+zFGr3Yj3PBHKdPMsevxnyncND+XawMjKwLgItN9jBFKvAhUnBZizzyohHXDnYxhpxQ/8AR30qBXWuKXYRqNBBdpRjJtS0jSM9lG2HwuXEQyC1uPjBVqyIaCEdYrZBK5xMSlb6WiH342ELas3YZ256cW3Ml/D8akYZ56mwVZo3z5ZdSZdufjS6wuR31HDSDZ9UORNIoQSMTwoYL7Mzzjb9vIu1vC7z2J81QOf0gcyIHv2SN057BGIz9b90aZAK3AjFI7iG7mszo+J7kEck81COFB6Sh40ODgn3T/RjbCFgizR6udcB/b0z2if7QvlxzvWFI0SIFIMPMA0ViKnq3+Jnh5QTJ5f0E/1fvegJY2VRRs0FxoUGp9EzHyiZ8QSCPjLS3XfrX9NuHS2HeWCmtaHyVaTPbptpBMILpBFXw23CR+2jI5xp57w0zuETdSszw+21deZeNG8/DIrK7z7/TuTJqyN7izgWFds5Yx5QS5ZIVUCvwabrglW+yvzwKOiWuGx4WzlymBOuHKhPJXXr+2DzM+JCMktjHI/p7Gpr/FiyaEXn57L5VGyVNhVI3bCgvg46jCNBRK8Vd+i2rQVUmyijQiA876Hn9W9YSSQGejLQcqC8AF79VnZAVWjmJj2sAHrYWFeDN2Ky7dbHxNzH+e0PRGiag4OvIf6BLUOjiFoUm4/Ilrou9H432+DXJQ9jbW8mEFQ8k8bb6FPZc0MbdZAWAAKn+P8g18bxIxmZfxjr6SM70D0u6K4mnu3o14yk04bh0EiI0XvPHood3AIRgS82KOs/8RrKwMezbUyBfNqdjTs4Pqf5eIItfQQQnHFJDqL4OdG0vwUANvyomWxDRIc+IUbN+ReBrq6jQVcO4UnQ0CB4q3H5w/kPcUacNP4Ec4EJfSWLAsNb3L7ajNDXZilfR3ZQX7CEGJvy3rU2ldqY9uFH9bYtHtGrglv+h7OWyHDnDBsVlr7eusGyqMm0mPBHHt/InKJ3wlbHfAf55d525dA+1b3nExK3N0OiULOflAtzodfaAK7RgwaSmhpFeRXcoLgK0i9YpX77snCHkuXN8Toc2spC0vwovX6eSQfMzQo9lbnujlIbvtbz5myYZTlqoIzufUVR1Q5tcMsyygyS3tv0K4mR0nR3PuR8QFNefRGYRSwlb1+v55A/fNv5+vnP2uh9YSsJeNmMY+QrDadKhsp1XcXiDgKOCfdt2rB60bVC+u21Lba/KVsjcRsh6G0euMlv7n7gXp2vvW9y7kODFxiK/xhCtw4LDEplSe1jWK1DB8QcbcHXMGCJrliPbdb6TRKZWr+HUf1pqjPC1jxN9to0lt9DAtAyd1++TgoMwMNUfGfsUZDLYgON55oAdus3lFUSM7GQ78+KPKzGRE8GSVaH/nmQ7tAPN8jm2ETsJGykSEx7YoWBiuMecS1g95OaYKvoP6Cc6WOVU+62l1plTlmqxIav3jJz0zvvtMDn+HAJxii6A5lGP6Ddlf8K3eeiyWWcOS+E7NclO+K4WGD8A6PJrXA54uqHezlI8Yuzsp1nbv8xVgzy+wiPdF68UzY+WjSMJH/L2pDVmQe5ZZ14QK+SWxxmrI4Ch225QEaExlFRWHWpX5w'

  playBeep: ->
    {audio} = ThreadUpdater
    audio.src or= ThreadUpdater.beep
    if audio.paused
      audio.play()
    else
      $.one audio, 'ended', ThreadUpdater.playBeep

  cb:
    checkpost: (e) ->
      return if e.detail.threadID isnt ThreadUpdater.thread.ID
      ThreadUpdater.postID = e.detail.postID
      ThreadUpdater.checkPostCount = 0
      ThreadUpdater.outdateCount = 0
      ThreadUpdater.setInterval()

    visibility: ->
      return if d.hidden
      # Reset the counter when we focus this tab.
      ThreadUpdater.outdateCount = 0
      if ThreadUpdater.seconds > ThreadUpdater.interval
        ThreadUpdater.setInterval()

    scrollBG: ->
      ThreadUpdater.scrollBG = if Conf['Scroll BG']
        -> true
      else
        -> not d.hidden

    interval: (e) ->
      val = parseInt @value, 10
      if val < 1 then val = 1
      ThreadUpdater.interval = @value = val
      $.cb.value.call @ if e

    load: ->
      return if @ isnt ThreadUpdater.req # aborted
      switch @status
        when 200
          ThreadUpdater.parse @
          if ThreadUpdater.thread.isArchived
            ThreadUpdater.kill()
          else
            ThreadUpdater.setInterval()
        when 404
          # XXX workaround for 4chan sending false 404s
          $.ajax g.SITE.urls.catalogJSON({boardID: ThreadUpdater.thread.board.ID}), onloadend: ->
            if @status is 200
              confirmed = true
              for page in @response
                for thread in page.threads
                  if thread.no is ThreadUpdater.thread.ID
                    confirmed = false
                    break
            else
              confirmed = false
            if confirmed
              ThreadUpdater.kill()
            else
              ThreadUpdater.error @
        else
          ThreadUpdater.error @

  kill: ->
    ThreadUpdater.thread.kill()
    ThreadUpdater.setInterval()
    $.event 'ThreadUpdate',
      404: true
      threadID: ThreadUpdater.thread.fullID

  error: (req) ->
    if req.status is 304
      ThreadUpdater.set 'status', ''
    ThreadUpdater.setInterval()
    unless req.status
      ThreadUpdater.set 'status', 'Connection Error', 'warning'
    else if req.status isnt 304
      ThreadUpdater.set 'status', "#{req.statusText} (#{req.status})", 'warning'

  setInterval: ->
    clearTimeout ThreadUpdater.timeoutID

    if ThreadUpdater.thread.isDead
      ThreadUpdater.set 'status', (if ThreadUpdater.thread.isArchived then 'Archived' else '404'), 'warning'
      ThreadUpdater.set 'timer', ''
      return

    # Fetching your own posts after posting
    if ThreadUpdater.postID and ThreadUpdater.checkPostCount < 5
      ThreadUpdater.set 'timer', '...', 'loading'
      ThreadUpdater.timeoutID = setTimeout ThreadUpdater.update, ++ThreadUpdater.checkPostCount * $.SECOND
      return

    unless Conf['Auto Update']
      ThreadUpdater.set 'timer', 'Update'
      return

    {interval} = ThreadUpdater
    if Conf['Optional Increase']
      # Lower the max refresh rate limit on visible tabs.
      limit = if d.hidden then 10 else 5
      j     = Math.min ThreadUpdater.outdateCount, limit

      # 1 second to 100, 30 to 300.
      cur = (Math.floor(interval * 0.1) or 1) * j * j
      ThreadUpdater.seconds = $.minmax cur, interval, 300
    else
      ThreadUpdater.seconds = interval

    ThreadUpdater.timeout()

  intervalShortcut: ->
    Settings.open 'Advanced'
    settings = $.id 'fourchanx-settings'
    $('input[name=Interval]', settings).focus()

  set: (name, text, klass) ->
    el = ThreadUpdater[name]
    if node = el.firstChild
      # Prevent the creation of a new DOM Node
      # by setting the text node's data.
      node.data = text
    else
      el.textContent = text
    el.className = klass ? (if text is '' then 'empty' else '')

  timeout: ->
    if ThreadUpdater.seconds
      ThreadUpdater.set 'timer', ThreadUpdater.seconds
      ThreadUpdater.timeoutID = setTimeout ThreadUpdater.timeout, 1000
    else
      ThreadUpdater.outdateCount++
      ThreadUpdater.update()
    ThreadUpdater.seconds--

  update: ->
    clearTimeout ThreadUpdater.timeoutID
    ThreadUpdater.set 'timer', '...', 'loading'
    if (oldReq = ThreadUpdater.req)
      delete ThreadUpdater.req
      oldReq.abort()
    ThreadUpdater.req = $.whenModified(
      g.SITE.urls.threadJSON({boardID: ThreadUpdater.thread.board.ID, threadID: ThreadUpdater.thread.ID}),
      'ThreadUpdater',
      ThreadUpdater.cb.load,
      {timeout: $.MINUTE}
    )

  updateThreadStatus: (type, status) ->
    return if not (hasChanged = ThreadUpdater.thread["is#{type}"] isnt status)
    ThreadUpdater.thread.setStatus type, status
    return if type is 'Closed' and ThreadUpdater.thread.isArchived
    change = if type is 'Sticky'
      if status
        'now a sticky'
      else
        'not a sticky anymore'
    else
      if status
        'now closed'
      else
        'not closed anymore'
    new Notice 'info', "The thread is #{change}.", 30

  parse: (req) ->
    postObjects = req.response.posts
    OP = postObjects[0]
    {thread} = ThreadUpdater
    {board} = thread
    [..., lastPost] = ThreadUpdater.postIDs

    # XXX Reject updates that falsely delete the last post.
    return if postObjects[postObjects.length-1].no < lastPost and
      new Date(req.getResponseHeader('Last-Modified')) - thread.posts.get(lastPost).info.date < 30 * $.SECOND

    g.SITE.Build.spoilerRange[board] = OP.custom_spoiler
    thread.setStatus 'Archived', !!OP.archived
    ThreadUpdater.updateThreadStatus 'Sticky', !!OP.sticky
    ThreadUpdater.updateThreadStatus 'Closed', !!OP.closed
    thread.postLimit = !!OP.bumplimit
    thread.fileLimit = !!OP.imagelimit
    thread.ipCount   = OP.unique_ips if OP.unique_ips?

    posts    = [] # new post objects
    index    = [] # existing posts
    files    = [] # existing files
    newPosts = [] # new post fullID list for API

    # Build the index, create posts.
    for postObject in postObjects
      ID = postObject.no
      index.push ID
      files.push ID if postObject.fsize

      # Insert new posts, not older ones.
      continue if ID <= lastPost

      # XXX Resurrect wrongly deleted posts.
      if (post = thread.posts.get(ID)) and not post.isFetchedQuote
        post.resurrect()
        continue

      newPosts.push "#{board}.#{ID}"
      node = g.SITE.Build.postFromObject postObject, board.ID
      posts.push new Post node, thread, board
      # Fetching your own posts after posting
      delete ThreadUpdater.postID if ThreadUpdater.postID is ID

    # Check for deleted posts.
    deletedPosts = []
    for ID in ThreadUpdater.postIDs when ID not in index
      thread.posts.get(ID).kill()
      deletedPosts.push "#{board}.#{ID}"
    ThreadUpdater.postIDs = index

    # Check for deleted files.
    deletedFiles = []
    for ID in ThreadUpdater.fileIDs when not (ID in files or "#{board}.#{ID}" in deletedPosts)
      thread.posts.get(ID).kill true
      deletedFiles.push "#{board}.#{ID}"
    ThreadUpdater.fileIDs = files

    unless posts.length
      ThreadUpdater.set 'status', ''
    else
      ThreadUpdater.set 'status', "+#{posts.length}", 'new'
      ThreadUpdater.outdateCount = 0

      unreadCount   = Unread.posts?.size
      unreadQYCount = Unread.postsQuotingYou?.size

      Main.callbackNodes 'Post', posts

      if d.hidden or not d.hasFocus()
        if Conf['Beep Quoting You'] and Unread.postsQuotingYou?.size > unreadQYCount
          ThreadUpdater.playBeep()
          ThreadUpdater.playBeep() if Conf['Beep']
        else if Conf['Beep'] and Unread.posts?.size > 0 and unreadCount is 0
          ThreadUpdater.playBeep()

      scroll = Conf['Auto Scroll'] and ThreadUpdater.scrollBG() and
        ThreadUpdater.root.getBoundingClientRect().bottom - doc.clientHeight < 25

      firstPost = null
      for post in posts
        unless QuoteThreading.insert post
          firstPost or= post.nodes.root
          $.add ThreadUpdater.root, post.nodes.root
      $.event 'PostsInserted', null, ThreadUpdater.root

      if scroll
        if Conf['Bottom Scroll']
          window.scrollTo 0, d.body.clientHeight
        else
          Header.scrollTo firstPost if firstPost

    # Update IP count in original post form.
    if OP.unique_ips? and (ipCountEl = $.id('unique-ips'))
      ipCountEl.textContent = OP.unique_ips
      ipCountEl.previousSibling.textContent = ipCountEl.previousSibling.textContent.replace(/\b(?:is|are)\b/, if OP.unique_ips is 1 then 'is' else 'are')
      ipCountEl.nextSibling.textContent = ipCountEl.nextSibling.textContent.replace(/\bposters?\b/, if OP.unique_ips is 1 then 'poster' else 'posters')

    $.event 'ThreadUpdate',
      404: false
      threadID: thread.fullID
      newPosts: newPosts
      deletedPosts: deletedPosts
      deletedFiles: deletedFiles
      postCount: OP.replies + 1
      fileCount: OP.images + !!OP.fsize
      ipCount: OP.unique_ips
