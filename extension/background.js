function change_preview_tab_to(url) {
	let should_change = false;
	chrome.tabs.query(
		{ active: true, currentWindow: true, url: 'http://127.0.0.1:3030/preview?fn_key=*' },
		function (tabs) {
			if (tabs.length > 0) {
				var tab = tabs[0];
				if (tab.url !== url) {
					should_change = true;
					chrome.tabs.query({ url: url }, function (tabs) {
						if (tabs.length > 0) {
							var tab = tabs[0];
							if (!tab.active) {
								chrome.tabs.update(tab.id, { active: true });
							}
						}
					});
				}
			}
		},
	);
}
function get_fn_key() {
	var url = 'http://127.0.0.1:3030/get_fn_key';
	fetch(url)
		.then((response) => response.json())
		.then((data) => {
			if (data.fn_key) {
				let url = 'http://127.0.0.1:3030/preview?fn_key=' + data.fn_key;
				change_preview_tab_to(url);
			}
		})
		.catch((error) => {
			console.error(error);
		});
}
function removeHashFragment(url) {
	return url.split('#')[0];
}
chrome.tabs.onUpdated.addListener(function (tabId, changeInfo, tab) {
	// Check if the URL of the tab was updated
	if (changeInfo.url) {
		// Get the URL of the updated tab without hash fragment
		const newUrl = removeHashFragment(changeInfo.url);

		// Find any existing tabs with the same URL without hash fragment
		chrome.tabs.query({}, function (tabs) {
			const closeTabIds = [];

			for (let t of tabs) {
				// Remove hash fragment from the tab URL
				const tabUrlWithoutHash = removeHashFragment(t.url);

				// Check if the tab has the same URL without hash fragment and is not the updated tab
				if (tabUrlWithoutHash === newUrl && t.id !== tabId) {
					closeTabIds.push(t.id);
					console.log('Close', t.url, 'this one is', newUrl);
				}
			}

			// Close any existing tabs with the same URL without hash fragment, except for the updated one
			chrome.tabs.remove(closeTabIds);
		});
	}
});

// chrome.tabs.onActivated.addListener(function (activeInfo) {
// 	// Get the currently active tab
// 	chrome.tabs.get(activeInfo.tabId, function (tab) {
// 		// Get the URL of the active tab
// 		const activeTabUrl = tab.url;
// 		console.log('Active tab URL:', activeTabUrl);
// 		const regex = /preview\?fn_key=([^&#]+)/;
// 		const match = activeTabUrl.match(regex);
// 		const fileNameWithPath = match ? match[1] : '';
// 		if (fileNameWithPath !== '') {
// 			console.log(fileNameWithPath);
// 			fetch('http://127.0.0.1:3030/editThis?path=' + fileNameWithPath);
// 		}
// 	});
// });

function check() {
	get_fn_key();
}

setInterval(check, 1000);
