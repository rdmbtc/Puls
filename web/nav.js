/* Puls — one shared navbar for every static page. Self-contained (injects its
   own styles + DOM), removes any existing <nav>, highlights the current page.
   Include with:  <script defer src="/nav.js"></script>  */
(function () {
  var path = (location.pathname.replace(/\/+$/, '') || '/');
  // [href, label]; brand first. External links use absolute URLs.
  var LINKS = [
    ['/pulse', 'Pulse'],
    ['/agent', 'Agent'],
    ['/versus', 'Versus'],
    ['/cli', 'CLI'],
    ['/mobile-download', 'Android'],
    ['/build', 'Build'],
    ['/explorer', 'Explorer'],
    ['/stats', 'Stats'],
    ['https://docs.pulsmarket.tech', 'Docs'],
  ];
  var active = function (href) {
    if (href.charAt(0) !== '/') return false;
    var h = href.replace(/\/+$/, '');
    return h === path;
  };

  var css = [
    '.pnav{position:sticky;top:0;z-index:9000;backdrop-filter:saturate(160%) blur(14px);',
    'background:rgba(7,9,18,.82);border-bottom:1px solid #1E263C;font-family:system-ui,-apple-system,"Segoe UI",Roboto,sans-serif}',
    '.pnav .in{max-width:1140px;margin:0 auto;padding:11px 20px;display:flex;align-items:center;gap:6px}',
    '.pnav .brand{display:flex;align-items:center;gap:9px;margin-right:14px;text-decoration:none;font-weight:800;font-size:16px;letter-spacing:-.4px}',
    '.pnav .brand img{width:24px;height:24px;border-radius:7px}',
    '.pnav .brand b{background:linear-gradient(100deg,#EC4899,#8B5CF6 55%,#2DD4BF);-webkit-background-clip:text;background-clip:text;color:transparent}',
    '.pnav a.l{color:#9AA6C0;text-decoration:none;font-size:13.5px;font-weight:600;padding:7px 10px;border-radius:9px;transition:.18s;white-space:nowrap}',
    '.pnav a.l:hover{color:#EAF0FF;background:rgba(255,255,255,.05)}',
    '.pnav a.l.on{color:#F472B6}',
    '.pnav .sp{flex:1}',
    '.pnav .cta{margin-left:6px;color:#08111f;background:linear-gradient(100deg,#EC4899,#F472B6 40%,#2DD4BF);border-radius:10px;padding:8px 16px;font-weight:700;font-size:13.5px;text-decoration:none;white-space:nowrap}',
    '.pnav .links{display:flex;align-items:center;gap:2px}',
    '.pnav .burger{display:none;background:none;border:1px solid #1E263C;color:#EAF0FF;border-radius:9px;padding:6px 10px;font-size:18px;cursor:pointer}',
    '.pnav .drawer{display:none;flex-direction:column;padding:6px 14px 14px;border-top:1px solid #1E263C;background:rgba(7,9,18,.96)}',
    '.pnav .drawer a{color:#EAF0FF;text-decoration:none;font-weight:600;font-size:15px;padding:11px 6px;border-bottom:1px solid rgba(255,255,255,.05)}',
    '.pnav .drawer a.on{color:#F472B6}',
    '.pnav.open .drawer{display:flex}',
    '@media(max-width:860px){.pnav .links{display:none}.pnav .burger{display:block}.pnav .cta{display:none}}',
  ].join('');
  var st = document.createElement('style'); st.textContent = css; document.head.appendChild(st);

  // Drop any pre-existing navbars so we don't double up.
  document.querySelectorAll('nav').forEach(function (n) { n.remove(); });

  var linkHTML = function (cls) {
    return LINKS.map(function (x) {
      return '<a class="' + cls + (active(x[0]) ? ' on' : '') + '" href="' + x[0] + '"' +
        (x[0].charAt(0) !== '/' ? ' target="_blank" rel="noopener"' : '') + '>' + x[1] + '</a>';
    }).join('');
  };

  var nav = document.createElement('nav');
  nav.className = 'pnav';
  nav.innerHTML =
    '<div class="in">' +
      '<a class="brand" href="/"><img src="/favicon.png" alt="Puls"><b>Puls</b></a>' +
      '<div class="links">' + linkHTML('l') + '</div>' +
      '<span class="sp"></span>' +
      '<a class="cta" href="/">Open app →</a>' +
      '<button class="burger" aria-label="Menu">☰</button>' +
    '</div>' +
    '<div class="drawer">' + linkHTML('') + '<a href="/">Open app →</a></div>';
  document.body.insertAdjacentElement('afterbegin', nav);
  nav.querySelector('.burger').addEventListener('click', function () { nav.classList.toggle('open'); });
})();
