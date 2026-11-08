# The chrome every page shares. `dsl.nav` is a slot the builder fills from the
# pages themselves, so adding a page updates the header without an edit here.
{
  lib,
  site,
  basePath,
}: {
  title,
  route,
  description ? null,
  navLabel ? title,
  navOrder ? 100,
  inner,
}:
let
  inherit (lib.dsl) el text page stylesheet nav;
in
page {
  inherit title route description navLabel navOrder;
  lang = "en";
  head = [ (stylesheet "/assets/css/style.css") ];
  body = [
    (el "header" { class = "site"; } [
      (el "a" { class = "brand"; href = "${basePath}/"; } [ (text site.title) ])
      (nav { })
      (el "a" { href = "https://github.com/${site.projectsUser}"; } [ (text "github") ])
    ])
    (el "main" { } inner)
    (el "footer" { } [
      (el "p" { } [
        (text site.description)
        (el "span" { class = "sep"; } [ (text "·") ])
        (el "a" { href = "mailto:${site.email}"; } [ (text "mail") ])
      ])
    ])
  ];
}
