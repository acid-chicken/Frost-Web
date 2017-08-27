<frost-create-status-form>
	<form onsubmit={ submit } onkeydown={ keydown } onkeyup={ keyup }>
		<h5>投稿する</h5>
		<textarea ref='text' placeholder='ねえ今どんな気持ち？' oninput={ input } required>{ text }</textarea>
		<span>{ textMax - getTextCount() }</span>
		<button type='submit' disabled={ !validTextCount() || lock }>投稿</button>
	</form>

	<style>
		@import "../styles/variables";

		:scope {
			> form {
				display: flex;
				flex-direction: column;

				> textarea {
					height: 6.6rem;
					font-size: 0.9rem;
				}

				> button {
					width: 5.5rem;
					align-self: flex-end;
				}

				> button:disabled {
					cursor: default;
				}
			}
		}
	</style>

	<script>
		const StreamingRest = require('../helpers/StreamingRest');
		this.textMax = 256;
		this.text = '';
		this.lock = false;

		// methods

		this.getTextCount = () => {
			return this.text.length;
		};

		this.validTextCount = () => {
			return this.getTextCount() != 0 && this.textMax - this.getTextCount() >= 0;
		};

		this.clear = () => {
			this.text = '';
			this.update();
		};

		// input events

		this.input = (e) => {
			this.text = this.refs.text.value; // 入力された文字列を反映
			this.update();
		};

		this.keydown = (e) => {
			const needSubmit = (e.metaKey || e.ctrlKey) && e.code == 'Enter';

			if (needSubmit && this.validTextCount()) {
				// lock submit button
				this.lock = true;
				this.createStatus();
			}
		};

		this.on('mount', () => {

			// methods

			this.createStatus = () => {
				(async () => {
					const streamingRest = new StreamingRest(this.webSocket);
					const rest = await streamingRest.requestAsync('post', '/posts/post_status', {body: {text: this.text}});
					this.clear();
					return 'success';
				})().catch(err => {
					console.error(err);
					return 'failed';
				}).then(status => {
					console.log(status);
					this.lock = false;
				});
			};

			// input events

			this.submit = (e) => {
				e.preventDefault();

				if (this.validTextCount()) {
					this.createStatus();
				}

				return false;
			};

			this.update();
		});
	</script>
</frost-create-status-form>
