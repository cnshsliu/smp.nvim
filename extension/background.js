function change_preview_tab_to(url) {
	let should_change = false;
	chrome.tabs.query(
		{ active: true, currentWindow: true, url: 'http://127.0.0.1:3030/preview/*' },
		function (tabs) {
			if (tabs.length > 0) {
				var tab = tabs[0];
				if (tab.url !== url) {
					console.log(tab.url, '!==', url);
					console.log('not the sames, should change it');
					should_change = true;
					chrome.tabs.query({ url: url }, function (tabs) {
						if (tabs.length > 0) {
							var tab = tabs[0];
							if (!tab.active) {
								chrome.tabs.update(tab.id, { active: true });
							}
						}
					});
				} else {
					console.log('already here, should not change');
				}
			} else {
				console.log('no active preview tab');
			}
		},
	);
}
function get_fn_key() {
	var url = 'http://127.0.0.1:3030/get_fn_key';
	fetch(url)
		.then((response) => response.json())
		.then((data) => {
			console.log(data.fn_key);
			if (data.fn_key) {
				let url = 'http://127.0.0.1:3030/preview/' + data.fn_key;
				change_preview_tab_to(url);
			}
		})
		.catch((error) => {
			console.error(error);
		});
}

setInterval(get_fn_key, 1000);
