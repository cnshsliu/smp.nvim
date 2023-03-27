function checkTabs() {
	chrome.tabs.query(
		{ url: 'http://127.0.0.1:3030/preview/*', currentWindow: true },
		function (tabs) {
			for (var i = 0; i < tabs.length; i++) {
				let tabId = tabs[i].id;
				chrome.tabs.sendMessage(
					tabId,
					{ command: 'find-and-switch', className: 'toThisTab', tabId: tabId },
					function (response) {
						if (response.success) {
							chrome.tabs.query(
								{ active: true, currentWindow: true, url: 'http://127.0.0.1:3030/preview/*' },
								function (tabs) {
									var tab = tabs[0];
									var url = tab.url;
									if (tab.id !== response.tabId) {
										chrome.tabs.update(response.tabId, { active: true });
									}
								},
							);
						} else {
							console.log('Element not found in tab ' + tabs[i].id);
						}
					},
				);
			}
		},
	);
}

setInterval(checkTabs, 2000);
