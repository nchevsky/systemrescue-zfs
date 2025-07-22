// Ensure preference can't be changed by users
lockPref("app.update.auto", false);
lockPref("app.update.enabled", false);
lockPref("intl.locale.matchOS", true);
// Allow user to change based on needs
defaultPref("browser.display.use_system_colors", true);
defaultPref("spellchecker.dictionary_path", "/usr/share/myspell");
defaultPref("browser.shell.checkDefaultBrowser", false);
// Preferences that should be reset every session
pref("browser.EULA.override", true);
// SystemRescue settings
pref("browser.startup.homepage_override.mstone", "ignore");
pref("browser.startup.homepage", "about:home");
// disable Firefox telemetry and surveys, don't annoy the user with it
pref("app.normandy.enabled", false);
pref("app.normandy.api_url", "");
pref("app.shield.optoutstudies.enabled", false);
pref("browser.newtabpage.activity-stream.feeds.telemetry", false);
pref("browser.newtabpage.activity-stream.telemetry", false);
pref("datareporting.healthreport.uploadEnabled", false);
pref("datareporting.policy.dataSubmissionEnabled", false);
pref("datareporting.policy.dataSubmissionPolicyBypassNotification", true);
pref("dom.private-attribution.submission.enabled", false);
pref("toolkit.telemetry.unified", false);
pref("toolkit.telemetry.enabled", false);
pref("toolkit.telemetry.server", "data:,");
pref("toolkit.telemetry.archive.enabled", false);
pref("toolkit.telemetry.newProfilePing.enabled", false);
pref("toolkit.telemetry.shutdownPingSender.enabled", false);
pref("toolkit.telemetry.updatePing.enabled", false);
pref("toolkit.telemetry.bhrPing.enabled", false);
pref("toolkit.telemetry.firstShutdownPing.enabled", false);
pref("toolkit.telemetry.coverage.opt-out", true);
pref("toolkit.coverage.opt-out", true);
pref("toolkit.coverage.endpoint.base", "");
// disable recommendations of extensions and features while browsing
pref("browser.newtabpage.activity-stream.asrouter.userprefs.cfr.addons", false);
pref("browser.newtabpage.activity-stream.asrouter.userprefs.cfr.features", false);
// disable advertising
pref("browser.newtabpage.activity-stream.showSponsoredTopSites", false);
pref("browser.newtabpage.activity-stream.showSponsored", false);
// disable "pocket" icon to not clutter the interface
pref("extensions.pocket.enabled", false);
// don't ever use DNS-over-HTTPS, we always want use the local resolver
// this is necessary for being able to resolve local hostnames e.g. in a split dns setup
// 5 means "off by choice"
pref("network.trr.mode", 5);