<frost-modal>
	<div class='modal-outer { opaque: modalOpaque }' onclick={ closeCancel } show={ modalShow }>
		<div class='modal'>
			<header>
				<h6>{ title }</h6>
				<div class='close' onclick={ closeCancel }><i class='fa fa-close'></i></div>
			</header>
			<div class='content'>
				<yield />
			</div>
		</div>
	</div>

	<style>
		:scope {
			> .modal-outer {
				position: fixed;
				top: 0;
				left: 0;
				display: flex;
				justify-content: center;
				align-items: center;
				height: 100%;
				width: 100%;
				z-index: 1;
				background-color: hsla(0, 0%, 0%, 0.3);
				transition: 300ms ease;
				opacity: 0;

				&.opaque {
					opacity: 1;
				}

				> .modal {
					background-color: hsl(0, 0%, 100%);
					border-radius: 0.5rem;

					> header {
						display: flex;
						justify-content: space-between;

						> * {
							user-select: none;
						}

						> h6 {
							margin-bottom: 0;
							padding: 0.75rem 0.75rem 0.75rem 2rem;
							cursor: default;
						}

						> .close {
							padding: 0 2rem;
							font-size: 1.75rem;
							display: flex;
							align-items: center;
							cursor: pointer;

							&:hover {
								background-color: hsl(0, 0%, 80%);
								border-radius: 0 0.5rem 0 0;
							}
						}
					}

					> .content {
						padding: 1rem 2rem 1rem;
					}
				}
			}
		}
	</style>

	<script>
		this.title = this.opts.dataTitle;
		const obs = this.opts.obs;

		this.modalOpaque = false;
		this.modalShow = false;

		this.show = () => {
			this.modalShow = true;
			this.update();

			setTimeout(() => {
				this.modalOpaque = true;
				this.update();
			}, 0);

			obs.trigger('ev:modal-showed');
		};

		this.close = () => {
			this.modalOpaque = false;
			this.update();

			setTimeout(() => {
				this.modalShow = false;
				this.update();

				obs.trigger('ev:modal-closed');
			}, 300);
		};

		this.closeOK = (e) => {
			this.ok = true;
			this.close();
		};

		this.closeCancel = (e) => {
			// イベント発生元(currentTarget)が'modal-outer' & イベント発生元(currentTarget)と実際にクリックされた要素(target)が別の時
			if (e != null && e.currentTarget.className.indexOf('modal-outer') != -1 && e.currentTarget.className != e.target.className) {
				return false;
			}

			this.ok = false;
			this.close();
		};

		// obs.on('modal-show', this.show);
		// obs.on('modal-close', this.close);

		this.on('mount', () => {
		});
	</script>
</frost-modal>

<frost-form-appauth>
	<form method='post' action='/oauth/authorize' ref='authForm'>
		<input type='hidden' name='transaction_id' value={ transactionId }>
		<input type='hidden' name='_csrf' value={ csrf }>
	</form>
	<div class='parent'>
		<div class='child'>
			<h6>{ app.name } があなたのアカウントにアクセスすることを許可しますか？</h6>
			<h6>要求されているアクセス権:</h6>
			<ul>
				<li each={ scope in scopes }>{ scope } - { scopeDetail[scope].description }</li>
			</ul>
			<p if={ scopes.length == 0 }>要求されているアクセス権はありません</p>

			<div class='controls'>
				<button class='accept button-primary' onclick={ acceptConfirm }>許可</button>
				<button class='reject' onclick={ reject }>拒否</button>
			</div>
		</div>
	</div>
	<frost-modal ref='modal' data-title='確認' obs={ obs }>
		<p>ロボットによるアクセスではないことを確認します。</p>
		<div id='recaptcha-appauth'></div>
		<button class='button-primary' onclick={ parent.checkRecaptcha }>確認</button>
	</frost-modal>

	<style>
		:scope {
			#recaptcha-appauth {
				user-select: none;
			}

			> .parent {
				/*
				display: flex;
				justify-content: center;
				margin: 3rem 0;
				*/

				> .child {
					padding: 2rem;
					border-radius: 0.5rem;
					border: 1px solid hsla(0, 0%, 0%, 0.15);

					.controls {
						display: flex;
						flex-direction: row-reverse;

						.accept {
							margin: 0 0 0 1rem;
						}
						.reject {
							margin: 0;
						}
					}
				}
			}
		}
	</style>

	<script>
		const riot = require('riot');
		const qs = require('qs');
		const fetchJson = require('../helpers/fetch-json');
		this.obs = riot.observable();
		this.status = 0; // 0:loading, 1: ok, 2:failed loading app
		this.app = {};

		this.scopeDetail = {
			'app.read': {
				description: '連携アプリに関するデータの読み取り'
			},
			'app.write': {
				description: '連携アプリに関するデータの書き込み'
			},
			'user.read': {
				description: 'ユーザーに関するデータの読み取り'
			},
			'user.write': {
				description: 'ユーザーに関するデータの書き込み'
			},
			'user.account.read': {
				description: 'あなたのアカウントに関する非公開データの読み取り'
			},
			'user.account.write': {
				description: 'あなたのアカウントに関する非公開データの書き込み'
			},
			'post.read': {
				description: 'ポストに関するデータの読み取り'
			},
			'post.write': {
				description: 'ポストに関するデータの書き込み'
			},
			'storage.read': {
				description: 'ストレージに関するデータの読み取り'
			},
			'storage.write': {
				description: 'ストレージに関するデータの書き込み'
			}
		};

		const q = qs.parse(location.search, { ignoreQueryPrefix: true });
		this.clientId = q.client_id;
		const scopeRaw = decodeURI(q.scope || '');
		if (scopeRaw == '') {
			this.scopes = [];
		}
		else {
			this.scopes = scopeRaw.split(' ');
		}

		(async () => {
			const appResult = await this.streamingRest.request('get', `/applications/${this.clientId}`);
			if (appResult.statusCode != 200) {
				this.status = 2;
				this.update();
				return;
			}
			this.app = appResult.response.application;
			this.status = 1;
			this.update();
		})();

		this.acceptConfirm = () => {
			this.refs.modal.show();
		};

		this.reject = () => {
			console.log('auth rejected'); // TODO
		};

		this.obs.on('ev:modal-closed', async () => {
			if (this.refs.modal.ok) {
				const recaptcha = grecaptcha.getResponse();

				// TODO: recaptcha responseを送信

				this.refs.authForm.submit();
			}
		});

		this.checkRecaptcha = () => {
			const res = grecaptcha.getResponse();
			if (res != '') {
				this.refs.modal.closeOK();
			}
		};

		this.on('mount', () => {
			grecaptcha.render('recaptcha-appauth', {
				sitekey: this.siteKey
			});
		});
	</script>
</frost-form-appauth>
