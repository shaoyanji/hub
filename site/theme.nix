# The one place the stylesheet path is written. layout.nix loads it for the
# authored pages; the flake passes it to the content step, which builds its own
# page wrapper around a markdown body.
{
  stylesheetHref = "/assets/css/style.css";
}
