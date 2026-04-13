# pagestart.html Sidebar-Umbau — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace jQuery Mobile panel-based navigation in pagestart.html with a CSS sidebar layout using existing Vue3 navbar for dynamic plugin navigation.

**Architecture:** New CSS grid layout (`lb-layout`) wraps a fixed sidebar (`lb-sidebar`) and scrollable main area (`lb-main`). The existing Vue3 navbar app is restructured from horizontal tabs into vertical sidebar links. jQuery Mobile page/panel/header wrappers are removed. A native `<dialog>` replaces the jQM reboot popup. Responsive: sidebar slides off-canvas on mobile with a backdrop overlay.

**Tech Stack:** CSS Grid/Flexbox, CSS Custom Properties (design tokens), Vue3, HTML5 `<dialog>`, HTML::Template

**Spec:** `docs/superpowers/specs/2026-04-13-pagestart-sidebar-design.md`

---

## File Map

### Modify
- `webfrontend/html/system/css/components.css` — Add layout, sidebar, header, modal CSS classes
- `templates/system/pagestart.html` — Complete restructure: sidebar + header + content
- `templates/system/pageend.html` — Footer + `<dialog>` replacing jQM popup
- `templates/system/pagestart_alternative.html` — Same restructure as pagestart
- `templates/system/pagestart_nopanels.html` — Simplified version without sidebar
- `webfrontend/html/system/css/main.css` — Remove old navbar/systemmenu styles

---

## Task 1: Add layout and sidebar CSS to components.css

**Files:**
- Modify: `webfrontend/html/system/css/components.css`

- [ ] **Step 1: Add layout CSS at end of components.css**

Append to the end of `webfrontend/html/system/css/components.css`:

```css
/* === Page Layout === */
.lb-layout {
  display: grid;
  grid-template-columns: 250px 1fr;
  min-height: 100vh;
}
.lb-main {
  display: flex;
  flex-direction: column;
  min-height: 100vh;
  overflow-x: hidden;
  background: var(--lb-bg);
}
.lb-content {
  flex: 1;
  padding: 20px 24px;
}
.lb-footer {
  text-align: center;
  padding: 20px;
}
.lb-footer-logo {
  width: 90px;
  height: 90px;
}

/* === Sidebar === */
.lb-sidebar {
  position: fixed;
  top: 0;
  left: 0;
  bottom: 0;
  width: 250px;
  background: var(--lb-sidebar-bg);
  color: var(--lb-sidebar-text);
  display: flex;
  flex-direction: column;
  overflow-y: auto;
  z-index: 1000;
  scrollbar-width: thin;
  scrollbar-color: rgba(255,255,255,.1) transparent;
}
.lb-sidebar::-webkit-scrollbar { width: 6px; }
.lb-sidebar::-webkit-scrollbar-thumb { background: rgba(255,255,255,.1); border-radius: 3px; }
.lb-sidebar-header {
  padding: 16px 18px;
  display: flex;
  align-items: center;
  gap: 10px;
  border-bottom: 1px solid var(--lb-sidebar-border);
}
.lb-sidebar-logo {
  width: 36px;
  height: 36px;
  background: var(--lb-primary);
  border-radius: var(--lb-radius-sm);
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 800;
  font-size: 15px;
  color: white;
  flex-shrink: 0;
}
.lb-sidebar-brand {
  font-weight: 700;
  font-size: 15px;
  color: var(--lb-sidebar-text);
}
.lb-sidebar-brand span {
  opacity: 0.6;
}
.lb-sidebar-version {
  font-size: 10px;
  opacity: 0.4;
}
.lb-sidebar-nav {
  flex: 1;
  overflow-y: auto;
  padding: 6px 0;
}
.lb-sidebar-section {
  padding: 16px 18px 6px;
  font-size: 10px;
  color: var(--lb-sidebar-section);
  text-transform: uppercase;
  letter-spacing: 1.5px;
  font-weight: 600;
  font-family: var(--lb-font);
}
.lb-sidebar-section:not(:first-child) {
  border-top: 1px solid var(--lb-sidebar-border);
  margin-top: 8px;
}
.lb-sidebar-link {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 8px 18px 8px 21px;
  font-size: 12px;
  color: var(--lb-sidebar-text);
  text-decoration: none;
  font-family: var(--lb-font);
  transition: background 0.15s ease;
}
.lb-sidebar-link:hover {
  background: var(--lb-sidebar-active-bg);
  color: var(--lb-sidebar-active-text);
}
.lb-sidebar-link.active {
  background: var(--lb-sidebar-active-bg);
  color: var(--lb-sidebar-active-text);
  border-left: 3px solid var(--lb-primary);
  padding-left: 18px;
}
.lb-sidebar-link .lb-sidebar-name {
  flex: 1;
}
.lb-sidebar-status {
  width: 7px;
  height: 7px;
  border-radius: 50%;
  background: var(--lb-primary);
  flex-shrink: 0;
}
.lb-sidebar-status.error {
  background: var(--lb-danger);
}
.lb-sidebar-badge {
  padding: 1px 5px;
  font-size: 8px;
  font-weight: 600;
  border-radius: 3px;
  background: rgba(202,138,4,.2);
  color: #ca8a04;
}
.lb-sidebar-footer {
  padding: 10px 18px;
  border-top: 1px solid var(--lb-sidebar-border);
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 10px;
  opacity: 0.4;
}
.lb-sidebar-backdrop {
  display: none;
  position: fixed;
  inset: 0;
  background: rgba(0,0,0,.5);
  z-index: 999;
}

/* === Header === */
.lb-header {
  display: flex;
  align-items: center;
  padding: 10px 24px;
  background: var(--lb-card-bg);
  border-bottom: 1px solid var(--lb-border-color);
  gap: 12px;
}
.lb-header-left {
  display: flex;
  align-items: center;
  gap: 6px;
}
.lb-header-title {
  flex: 1;
  font-size: 18px;
  font-weight: 700;
  color: var(--lb-text);
  font-family: var(--lb-font);
  margin: 0;
}
.lb-header-actions {
  display: flex;
  align-items: center;
  gap: 8px;
}
.lb-header-btn {
  width: 34px;
  height: 34px;
  background: var(--lb-btn-bg);
  border-radius: var(--lb-radius-sm);
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 15px;
  color: var(--lb-text-muted) !important;
  text-decoration: none !important;
  transition: background 0.15s ease;
}
.lb-header-btn:hover {
  background: var(--lb-primary);
  color: white !important;
}
.lb-header-btn.headerbutton_red {
  background: var(--lb-danger);
  color: white !important;
}
.lb-header-btn.headerbutton_blue {
  background: var(--lb-info);
  color: white !important;
}
.lb-sidebar-toggle {
  display: none;
  align-items: center;
  justify-content: center;
  width: 34px;
  height: 34px;
  background: none;
  border: none;
  font-size: 18px;
  color: var(--lb-text-muted);
  cursor: pointer;
}

/* === Help Panel === */
.lb-helppanel {
  position: fixed;
  top: 0;
  right: 0;
  bottom: 0;
  width: 300px;
  background: var(--lb-card-bg);
  border-left: 1px solid var(--lb-border-color);
  transform: translateX(300px);
  transition: transform 0.3s ease;
  z-index: 1001;
  overflow-y: auto;
  padding: 0;
}
.lb-helppanel.open {
  transform: translateX(0);
}
.lb-helppanel-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 16px 20px;
  border-bottom: 1px solid var(--lb-border-color);
}
.lb-helppanel-header h2 {
  margin: 0;
  font-size: 16px;
  color: var(--lb-text);
}
.lb-helppanel-close {
  background: none;
  border: none;
  font-size: 20px;
  color: var(--lb-text-muted);
  cursor: pointer;
}
.lb-helppanel-content {
  padding: 16px 20px;
  font-size: 14px;
  color: var(--lb-text-secondary);
}

/* === Modal (dialog) === */
.lb-modal {
  border: none;
  border-radius: var(--lb-radius);
  box-shadow: 0 4px 24px rgba(0,0,0,.2);
  max-width: 600px;
  padding: 0;
  background: var(--lb-card-bg);
  color: var(--lb-text);
}
.lb-modal::backdrop {
  background: rgba(0,0,0,.5);
}
.lb-modal-header {
  padding: 16px 20px;
  border-bottom: 1px solid var(--lb-border-color);
}
.lb-modal-header h2 {
  margin: 0;
  font-size: 18px;
}
.lb-modal-content {
  padding: 20px;
  text-align: center;
}

/* === Responsive === */
@media (max-width: 768px) {
  .lb-layout {
    grid-template-columns: 1fr;
  }
  .lb-sidebar {
    transform: translateX(-250px);
    transition: transform 0.3s ease;
  }
  .lb-sidebar.open {
    transform: translateX(0);
  }
  .lb-sidebar-backdrop.open {
    display: block;
  }
  .lb-sidebar-toggle {
    display: flex;
  }
  .lb-header {
    padding: 10px 12px;
  }
  .lb-content {
    padding: 12px;
  }
}
```

- [ ] **Step 2: Verify no syntax errors**

Open any page in browser, open DevTools, check Console for CSS errors. The new classes won't affect anything yet because no HTML uses them.

- [ ] **Step 3: Commit**

```bash
git add webfrontend/html/system/css/components.css
git commit -m "feat(css): add layout, sidebar, header, helppanel, modal classes"
```

---

## Task 2: Rewrite pagestart.html

**Files:**
- Modify: `templates/system/pagestart.html`

- [ ] **Step 1: Replace the entire file content**

Replace the full content of `templates/system/pagestart.html` with:

```html
<!-- pagestart.html START -->
<div class="lb-layout">
	<!-- Sidebar -->
	<aside class="lb-sidebar" id="lb-sidebar">
		<div class="lb-sidebar-header">
			<div class="lb-sidebar-logo">L</div>
			<div>
				<div class="lb-sidebar-brand"><span>Lox</span>Berry</div>
				<div class="lb-sidebar-version"><TMPL_VAR LBVERSION></div>
			</div>
		</div>
		<nav class="lb-sidebar-nav">
			<!-- System Menu (static) -->
			<div class="lb-sidebar-section"><TMPL_VAR HEADER.PANEL_SYSTEMSETTINGS></div>
			<a class="lb-sidebar-link" href="/admin/system/index.cgi"><span class="lb-sidebar-name"><TMPL_VAR HEADER.PANEL_HOME></span></a>
			<a class="lb-sidebar-link" href="/admin/system/myloxberry.cgi"><span class="lb-sidebar-name"><TMPL_VAR HEADER.PANEL_MYLOXBERRY></span></a>
			<a class="lb-sidebar-link" href="/admin/system/admin.cgi"><span class="lb-sidebar-name"><TMPL_VAR HEADER.PANEL_ADMIN></span></a>
			<a class="lb-sidebar-link" href="/admin/system/miniserver.cgi"><span class="lb-sidebar-name"><TMPL_VAR HEADER.PANEL_MINISERVER></span></a>
			<a class="lb-sidebar-link" href="/admin/system/network.cgi"><span class="lb-sidebar-name"><TMPL_VAR HEADER.PANEL_NETWORK></span></a>
			<a class="lb-sidebar-link" href="/admin/system/plugininstall.cgi"><span class="lb-sidebar-name"><TMPL_VAR HEADER.PANEL_PLUGININSTALL></span></a>
			<a class="lb-sidebar-link" href="/admin/system/updates.cgi"><span class="lb-sidebar-name"><TMPL_VAR HEADER.PANEL_UPDATES></span></a>
			<a class="lb-sidebar-link" href="/admin/system/logmanager.cgi"><span class="lb-sidebar-name">Log Manager</span></a>
			<a class="lb-sidebar-link" href="/admin/system/services.php"><span class="lb-sidebar-name"><TMPL_VAR HEADER.PANEL_SERVICES></span></a>
			<a class="lb-sidebar-link" href="/admin/system/power.cgi"><span class="lb-sidebar-name"><TMPL_VAR HEADER.PANEL_REBOOT></span></a>
			<a class="lb-sidebar-link" href="/admin/system/mailserver.cgi"><span class="lb-sidebar-name"><TMPL_VAR HEADER.PANEL_MAILSERVER></span></a>
			<a class="lb-sidebar-link" href="/admin/system/translate.cgi"><span class="lb-sidebar-name"><TMPL_VAR HEADER.PANEL_TRANSLATE></span></a>
			<a class="lb-sidebar-link" href="/admin/system/tools/filemanager/filemanager.php"><span class="lb-sidebar-name"><TMPL_VAR HEADER.PANEL_FILEMANAGER></span></a>
			<a class="lb-sidebar-link" href="/admin/system/netshares.cgi"><span class="lb-sidebar-name"><TMPL_VAR HEADER.PANEL_NETSHARES></span></a>
			<a class="lb-sidebar-link" href="/admin/system/usbstorage.cgi"><span class="lb-sidebar-name"><TMPL_VAR HEADER.PANEL_USBSTORAGE></span></a>
			<a class="lb-sidebar-link" href="/admin/system/remote.cgi"><span class="lb-sidebar-name"><TMPL_VAR HEADER.PANEL_REMOTE></span></a>
			<a class="lb-sidebar-link" href="/admin/system/mqtt.cgi"><span class="lb-sidebar-name"><TMPL_VAR HEADER.PANEL_MQTT></span></a>
			<a class="lb-sidebar-link" href="/admin/system/backup.cgi"><span class="lb-sidebar-name"><TMPL_VAR HEADER.PANEL_BACKUP></span></a>
			<a class="lb-sidebar-link" href="/admin/system/tools/terminal" target="_blank"><span class="lb-sidebar-name"><TMPL_VAR HEADER.PANEL_TERMINAL></span></a>
			<a class="lb-sidebar-link" href="/admin/system/donate.cgi"><span class="lb-sidebar-name"><TMPL_VAR HEADER.PANEL_DONATE></span></a>
		</nav>
		<div class="lb-sidebar-footer">
			<div class="lb-sidebar-status"></div>
			<span>LoxBerry</span>
		</div>
	</aside>
	<!-- /Sidebar -->

	<!-- Sidebar Backdrop (mobile) -->
	<div class="lb-sidebar-backdrop" id="lb-sidebar-backdrop" onclick="toggleSidebar()"></div>

	<!-- Help Panel -->
	<aside class="lb-helppanel" id="helppanel">
		<div class="lb-helppanel-header">
			<h2><TMPL_VAR HEADER.TITLE_HELP></h2>
			<button class="lb-helppanel-close" onclick="toggleHelpPanel()">&times;</button>
		</div>
		<div class="lb-helppanel-content">
			<p><a href="<TMPL_VAR HELPLINK>" target="blank"><TMPL_VAR HEADER.TITLE_HELPLINK></a></p>
			<TMPL_VAR HELPTEXT>
		</div>
	</aside>

	<!-- Main -->
	<div class="lb-main">
		<!-- Header -->
		<header class="lb-header">
			<div class="lb-header-left">
				<button class="lb-sidebar-toggle" id="btn-sidebar-toggle" onclick="toggleSidebar()">
					<i class="pi pi-bars"></i>
				</button>
				<a href="/admin/system/index.cgi" class="lb-header-btn pi pi-home"></a>
			</div>
			<h1 class="lb-header-title"><TMPL_VAR TEMPLATETITLE></h1>
			<div class="lb-header-actions">
				<div id="update_alert" style="display:none; width:30px; height:30px; background-repeat: no-repeat; background-image: url('/system/images/update-running.svg');"></div>
				<a id="btnnotifies" href="/admin/system/tools/showallnotifications.cgi" class="lb-header-btn pi pi-bell"></a>
				<a id="btninfo" href="#" class="lb-header-btn pi pi-question-circle" onclick="toggleHelpPanel(); return false;"></a>
				<a id="btnpower" href="/admin/system/power.cgi" class="lb-header-btn pi pi-power-off"></a>
			</div>
		</header>

		<!-- Vue Navbar (horizontal sub-tabs) -->
		<div id="vuenavbar" :key="componentKey">
			<div class="vuenavbarcontainer">
				<template v-for="(element, index) in menu" :key="index">
					<a class="vuenavbarelement" :href="element.URL" @mouseover="hover(index, true)" @click="menuclick(index, null, $event)" :class="{ vuenavbarelement_active: element.active }">
					{{element.Name}}
					{{get_notification_count( element )}}
					<transition name="fade">
					<div style="position:relative;" class="notifyNavBar notifyNavBarBlue" v-show="element?.infoCount>0">{{element.infoCount}}</div>
					</transition>
					<transition name="fade">
					<div style="position:relative;" class="notifyNavBar notifyNavBarRed" v-show="element?.errorCount>0">{{element.errorCount}}</div>
					</transition>
					</a>
				</template>
			</div>
			<div class="vuenavbarsubcontainer">
				<template v-for="(element, index) in menu" :key="index">
					<a v-for="(subelement, subindex) in element.Submenu" :href="subelement.URL" @click="menuclick(index, subindex, $event)" :key="subindex" class="vuenavbarsubelement" :class="{ vuenavbarsubelement_active: subelement.active }" v-show="menu[index]?.show">
						{{subelement.Name}}
						{{get_notification_count( subelement )}}
					<transition name="fade">
					<div style="position:relative;right:-5px;" class="notifyNavBar notifyNavBarBlue" v-show="subelement?.infoCount>0">{{element.infoCount}}</div>
					</transition>
					<transition name="fade">
					<div style="position:relative;right:-5px;" class="notifyNavBar notifyNavBarRed" v-show="subelement?.errorCount>0">{{element.errorCount}}</div>
					</transition>
					</a>
				</template>
			</div>
		</div>

		<!-- Sidebar active link highlight -->
		<script>
		// Highlight current page in sidebar
		(function() {
			var currentPath = window.location.pathname + window.location.search;
			var links = document.querySelectorAll('.lb-sidebar-link');
			links.forEach(function(link) {
				if (link.getAttribute('href') === currentPath) {
					link.classList.add('active');
				}
			});
		})();

		// Sidebar toggle (mobile)
		function toggleSidebar() {
			document.getElementById('lb-sidebar').classList.toggle('open');
			document.getElementById('lb-sidebar-backdrop').classList.toggle('open');
		}

		// Help panel toggle
		function toggleHelpPanel() {
			document.getElementById('helppanel').classList.toggle('open');
		}
		</script>

		<!-- Vue Navbar CSS -->
		<style>
.vuenavbarcontainer {
	border-top: 1px solid var(--lb-border-color);
	display:flex;
	flex-direction:row;
	flex-wrap:nowrap;
	justify-content: center;
	align-items: center;
	background-color: var(--lb-sidebar-bg);
	overflow-x: auto;
	-webkit-overflow-scrolling: touch;
	scrollbar-width: none;
}
.vuenavbarcontainer::-webkit-scrollbar { display: none; }
.vuenavbarelement {
	flex: 1;
	text-shadow:none;
	padding: 10px 20px;
	color: var(--lb-sidebar-text) !important;
	font-size: 13px;
	font-weight: bold;
	text-align: center;
	text-decoration: none;
	min-height:18px;
	white-space: nowrap;
	min-width: fit-content;
	font-family: var(--lb-font);
}
@media (max-width: 768px) {
	.vuenavbarelement { font-size: 11px; padding: 8px 12px; }
}
@media (max-width: 480px) {
	.vuenavbarelement { font-size: 10px; padding: 6px 8px; }
}
.vuenavbarelement:hover { background-color: var(--lb-primary-hover, #5A8E1C); }
.vuenavbarelement_active { background-color: var(--lb-primary); color: white !important; }
.vuenavbarsubcontainer {
	display:flex;
	flex-direction:row;
	flex-wrap:nowrap;
	justify-content: flex-start;
	align-items: stretch;
	background-color: var(--lb-sidebar-bg);
}
.vuenavbarsubelement {
	flex:1;
	text-shadow:none;
	padding: 5px 10px;
	border: 1px solid var(--lb-border-color);
	font-size: 13px;
	font-weight: bold;
	text-align: center;
	background-color: var(--lb-btn-bg);
	color: var(--lb-text) !important;
	text-decoration: none;
	font-family: var(--lb-font);
}
.vuenavbarsubelement:hover {
	background-color: var(--lb-primary-hover, #5A8E1C);
	border-color: var(--lb-primary-hover, #5A8E1C);
	color: white !important;
}
.vuenavbarsubelement_active {
	background-color: var(--lb-primary);
	color: white !important;
}
.fade-enter-active, .fade-leave-active { transition: opacity 0.8s ease; }
.fade-enter-from, .fade-leave-to { opacity: 0; }
		</style>

		<TMPL_VAR JSONMENU>
		<script src="/system/scripts/vue3/vue3.js"></script>
		<script>
		function createnavbar() {
			console.log("jsonmenu init");
			const vuenavbar = {
				data() {
					var menu = this.getMenuData();
					console.log("Menu", menu);
					componentKey = 0;
					return { menu, componentKey };
				},
				methods: {
					getMenuData() {
						var menuelement = document.getElementById('jsonmenu');
						var menuobj = JSON.parse(menuelement.textContent);
						console.log("pathname", window.location.pathname+window.location.search);
						var response = this.elementSetActive( menuobj );
						menuobj = response[0];
						console.log("Final menuobj", menuobj);
						return menuobj;
					},
					elementSetActive( menuobj ) {
						var vm = this;
						var currentUrl = window.location.pathname+window.location.search;
						var elementsActive = 0;
						for( let index in menuobj ) {
							element = menuobj[index];
							menuobj[index].show=false;
							menuobj[index].infoCount = 0;
							menuobj[index].errorCount = 0;
							if( element.Submenu ) {
								var response = vm.elementSetActive( element.Submenu );
								menuobj[index].Submenu = response[0];
								if( !menuobj[index].active ) {
									menuobj[index].active = response[1];
								}
								if( menuobj[index].active == 1 ) {
									menuobj[index].show = true;
								}
							}
							else if( element.URL && element.URL == currentUrl ) {
								if( !menuobj[index].active ) {
									menuobj[index].active = 1;
									elementsActive = 1;
								}
							}
							else {
								if( !menuobj[index].active ) {
									menuobj[index].active = 0;
								}
							}
						};
						return [ menuobj, elementsActive ];
					},
					hover( index, active ) {
						for( let i in this.menu ) { this.menu[i].show = false; }
						this.menu[index].show = true;
					},
					menuclick( mainindex, subindex=null, event=null ) {
						event.preventDefault();
						if( subindex == null ) {
							if( !this.menu[mainindex].Submenu ) {
								this.callUrl(mainindex);
								return;
							}
							this.hover( mainindex, true );
							return;
						} else {
							this.callUrl(mainindex, subindex);
						}
					},
					callUrl( mainindex, subindex=null ) {
						var url, target;
						if( subindex != null ) {
							url = this.menu[mainindex].Submenu[subindex].URL;
							target = typeof this.menu[mainindex].Submenu[subindex].target !== 'undefined' ? this.menu[mainindex].Submenu[subindex].target : '_self';
						} else {
							url = this.menu[mainindex].URL;
							target = typeof this.menu[mainindex].target !== 'undefined' ? this.menu[mainindex].target : '_self';
						}
						window.open(url, target);
					},
					get_notification_count( element ) {
						if( !element.Notify_Package ) return;
						fetch('/admin/system/ajax/ajax-notification-handler.cgi', {
							method: 'POST',
							headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
							body: 'action=get_notification_count&package='+encodeURIComponent(element.Notify_Package)+'&name='+encodeURIComponent(element?.Notify_Name)
						})
						.then( response => response.json())
						.then( data => {
							if( data[0] > 0 ) element.errorCount = data[2];
							else if( data[1] > 0 ) element.infoCount = data[2];
							else { element.errorCount = 0; element.infoCount = 0; }
						});
					}
				}
			}
			navbarglobal = Vue.createApp(vuenavbar).mount('#vuenavbar');
		}
		if( document.getElementById('jsonmenu') ) { createnavbar(); }

		// Notification bell
		const notifyCachetimeSec = 30;
		btnnotifies_get();
		setInterval(function(){ btnnotifies_get(); }, notifyCachetimeSec*1000);

		function btnnotifies_get(force) {
			let notifyCount, notifyTimestamp = 0;
			try {
				let notifStore = sessionStorage.getItem("notifyCount");
				notifyCount = JSON.parse(notifStore);
				notifyTimestamp = notifyCount.ts;
			} catch(error) { notifyCount = new Object(); }
			if( (notifyTimestamp+notifyCachetimeSec*1000) < Date.now() || force == true) {
				fetch('/admin/system/ajax/ajax-notification-handler.cgi', {
					method: 'POST',
					headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
					body: 'action=get_notification_count'
				})
				.then( response => response.json())
				.then( data => { btnnotifies_setStorage(data[0], data[1]); });
			} else { btnnotifies_setcss( notifyCount ); }
		}
		function btnnotifies_setStorage(errorCount, infoCount) {
			let notifyCount = new Object();
			notifyCount.errorCount = errorCount;
			notifyCount.infoCount = infoCount;
			notifyCount.ts = Date.now();
			sessionStorage.setItem("notifyCount", JSON.stringify(notifyCount));
			btnnotifies_setcss(notifyCount);
		}
		function btnnotifies_setcss(data) {
			if( data.errorCount > 0 ) {
				$("#btnnotifies").addClass("headerbutton_red").removeClass("headerbutton_blue");
			} else if(data.infoCount > 0 ) {
				$("#btnnotifies").removeClass("headerbutton_red").addClass("headerbutton_blue");
			} else {
				$("#btnnotifies").removeClass("headerbutton_red").removeClass("headerbutton_blue");
			}
		}
		</script>

		<!-- Content -->
		<TMPL_VAR NAVBAR_PLAIN>
		<div id="page_content" class="lb-content page_content">
<!-- pagestart.html END -->
```

- [ ] **Step 2: Verify the template compiles**

Open any Core page (e.g. myloxberry.cgi) in browser. Check that:
- Sidebar appears on the left with system links
- Header shows page title + action buttons
- Content area shows the page content
- Vue navbar tabs appear below header (if plugin page)

- [ ] **Step 3: Commit**

```bash
git add templates/system/pagestart.html
git commit -m "feat(pagestart): replace jQM panels with CSS sidebar layout"
```

---

## Task 3: Rewrite pageend.html

**Files:**
- Modify: `templates/system/pageend.html`

- [ ] **Step 1: Replace the entire file content**

Replace `templates/system/pageend.html` with:

```html
<!-- pageend.html START -->
				</div>

				<!-- Footer -->
				<footer class="lb-footer">
					<a id="btnhomefooter" href="/admin/system/index.cgi">
						<img src="/system/images/icons/main_myloxberry.svg" class="lb-footer-logo" alt="LoxBerry">
					</a>
				</footer>
			</div>
			<!-- /lb-main -->
		</div>
		<!-- /lb-layout -->

		<!-- Reboot Force Dialog -->
		<dialog class="lb-modal" id="popupRebootForce">
			<div class="lb-modal-header">
				<h2><TMPL_VAR POWER.FORCEREBOOT_HEADER></h2>
			</div>
			<div class="lb-modal-content">
				<img src="/system/images/reboot_required_big.svg" style="width:60px;">
				<p><b><TMPL_VAR POWER.FORCEREBOOT_CONTENT></b></p>
				<p id="popupRebootForceReason"></p>
				<p><TMPL_VAR POWER.FORCEREBOOT_APOLOGY></p>
				<a class="lb-btn lb-btn-sm lb-btn-icon" href="/admin/system/power.cgi"><i class="pi pi-power-off"></i> <TMPL_VAR HEADER.PANEL_REBOOT></a>
			</div>
		</dialog>

		<!-- Status Bar -->
		<div id="footerLBStatusbar" style="display:none;z-index:1000;overflow:hidden;background-color:#6dac20;position:fixed;bottom:0;height:30px;width:100%;padding:6px;text-align:center;color:white;"></div>

<script>
$( document ).ready(function() {
	const mainiconsRefreshSec = 13;
	mainicons_get();
	var refresh_main_icons_interval_timer = setInterval(mainicons_get, mainiconsRefreshSec*1000);

	function mainicons_get() {
		let mainiconsTimestamp = 0;
		try {
			let mainiconsStore = sessionStorage.getItem("mainicons");
			data = JSON.parse(mainiconsStore);
			mainiconsTimestamp = data.ts;
		} catch(error) { data = new Object(); }
		if( (mainiconsTimestamp+mainiconsRefreshSec*1000) < Date.now() ) {
			fetch('/admin/system/ajax/ajax-main-icons-handler.php')
			.then( response => response.json())
			.then( data => { mainicons_setStorage(data); });
		} else { mainicons_setcss(data); }
	}

	function mainicons_setStorage(data) {
		data.ts = Date.now();
		sessionStorage.setItem("mainicons", JSON.stringify(data));
		mainicons_setcss(data);
	}

	function mainicons_setcss(data) {
		if( data.reboot_required == 1 ) {
			$("#btnpower").addClass("headerbutton_red");
		} else {
			$("#btnpower").removeClass("headerbutton_red");
		}
		if (data.reboot_force == 1 && data.update_running == 0) {
			if(data.reboot_force_reason.length > 0) {
				$("#popupRebootForceReason").html(data.reboot_force_reason);
			}
			next_reboot_force_popup_time = sessionStorage.getItem("loxberry_reboot_force");
			if(next_reboot_force_popup_time === "null")
				next_reboot_force_popup_time = 0;
			if( next_reboot_force_popup_time < Date.now()) {
				document.getElementById('popupRebootForce').showModal();
				sessionStorage.setItem("loxberry_reboot_force", Date.now()+2*60*1000);
			}
		}
		if( data.update_running == 1) {
			$("#footerLBStatusbar").fadeIn().text("<TMPL_VAR UPDATES.LBU_UPDATE_WARNING_FOOTER> ("+data.which.toString()+")");
		} else {
			$("#footerLBStatusbar").fadeOut();
		}
	}
});
</script>

<div id="lang" style="display: none"><TMPL_VAR LANG></div>
<!-- pageend.html END -->
```

Key change: `$("#popupRebootForce").popup("open")` replaced with `document.getElementById('popupRebootForce').showModal()`.

- [ ] **Step 2: Commit**

```bash
git add templates/system/pageend.html
git commit -m "feat(pageend): replace jQM popup with native dialog, clean footer"
```

---

## Task 4: Update pagestart_alternative.html and pagestart_nopanels.html

**Files:**
- Modify: `templates/system/pagestart_alternative.html`
- Modify: `templates/system/pagestart_nopanels.html`

- [ ] **Step 1: Make pagestart_alternative.html identical to pagestart.html**

The alternative version was a copy with the same panels. Since the new sidebar is universal, make it a symlink or copy:

```bash
cp templates/system/pagestart.html templates/system/pagestart_alternative.html
```

- [ ] **Step 2: Simplify pagestart_nopanels.html**

Replace `templates/system/pagestart_nopanels.html` with a minimal version without sidebar:

```html
<!-- pagestart.html START -->
<div class="lb-layout" style="grid-template-columns: 1fr;">
	<!-- Main (no sidebar) -->
	<div class="lb-main">
		<header class="lb-header">
			<h1 class="lb-header-title"><TMPL_VAR TEMPLATETITLE></h1>
		</header>
		<TMPL_VAR TOPNAVBAR>
		<TMPL_VAR NAVBARJS>
		<div id="page_content" class="lb-content page_content">
<!-- pagestart.html END -->
```

- [ ] **Step 3: Commit**

```bash
git add templates/system/pagestart_alternative.html templates/system/pagestart_nopanels.html
git commit -m "feat(pagestart): update alternative and nopanels variants"
```

---

## Task 5: Clean up main.css old navigation styles

**Files:**
- Modify: `webfrontend/html/system/css/main.css`

- [ ] **Step 1: Remove old systemmenu styles**

Find and remove the `ul.lb-systemmenu` block (~lines 483-508):
```css
ul.lb-systemmenu li { ... }
ul.lb-systemmenu a { ... }
ul.lb-systemmenu li:hover { ... }
ul.lb-systemmenu li:hover a { ... }
ul.lb-systemmenu li.lb-nonhover { ... }
```

These are no longer needed — the sidebar uses `.lb-sidebar-link` classes.

- [ ] **Step 2: Remove old headerbutton styles**

The `.headerbutton`, `.headerbutton_red`, `.headerbutton_blue` styles were inline in pagestart.html and are now replaced by `.lb-header-btn`. However, the `headerbutton_red`/`headerbutton_blue` class names are still used by the notification JS — keep those class names but they now target `.lb-header-btn` (already handled in components.css).

- [ ] **Step 3: Commit**

```bash
git add webfrontend/html/system/css/main.css
git commit -m "cleanup(main.css): remove old systemmenu navigation styles"
```

---

## Task 6: Deploy and verify on LoxBerry

**Files:** None (testing only)

- [ ] **Step 1: Deploy all changed files**

```bash
# CSS
cp webfrontend/html/system/css/components.css L:/webfrontend/html/system/css/
cp webfrontend/html/system/css/main.css L:/webfrontend/html/system/css/

# Templates (CRLF -> LF)
for f in templates/system/pagestart.html templates/system/pageend.html templates/system/pagestart_alternative.html templates/system/pagestart_nopanels.html; do
  sed 's/\r$//' "$f" > "L:/$f"
done
```

- [ ] **Step 2: Test Desktop**

Open `http://loxberry/admin/system/myloxberry.cgi` with Ctrl+Shift+R:
- Sidebar visible on left with system links
- Current page highlighted in sidebar
- Header shows page title + notification bell + power button
- Content area shows page content
- Vue navbar tabs work (switch between pages)
- Help panel opens/closes on ? button click
- Theme still applies (test with different themes)

- [ ] **Step 3: Test Mobile**

Open in phone or DevTools responsive mode:
- Sidebar hidden by default
- Hamburger button visible in header
- Click hamburger → sidebar slides in from left
- Click backdrop → sidebar closes
- Content is full-width

- [ ] **Step 4: Test Plugin page**

Open a plugin (e.g. Stats4Lox). Verify:
- Plugin content renders inside lb-content
- Plugin's jQuery Mobile elements still work
- Vue navbar shows plugin tabs correctly

- [ ] **Step 5: Test Reboot popup**

If a reboot is pending (or simulate by editing SessionStorage), verify the `<dialog>` modal opens correctly.
