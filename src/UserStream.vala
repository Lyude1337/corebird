

// See https://dev.twitter.com/docs/streaming-apis/messages
enum StreamMessageType {
	DELETE,
	SCRUB_GEO,
	LIMIT,
	DISCONNECT,
	FRIENDS,
	EVENT,
	WARNING,

	TWEET,
}


class UserStream : Object{
	private static UserStream instance;
	public static new UserStream get(){
		if(instance == null)
			instance = new UserStream();

		return instance;
	}



	private Rest.OAuthProxy proxy;
	private StringBuilder data                    = new StringBuilder();
	private SList<IMessageReceiver> receivers 	  = new SList<IMessageReceiver>();



	public UserStream() {
		proxy = new Rest.OAuthProxy(
        	"0rvHLdbzRULZd5dz6X1TUA",						//Consumer Key
        	"oGrvd6654nWLhzLcJywSW3pltUfkhP4BnraPPVNhHtY", 	//Consumer Secret
        	"https://userstream.twitter.com/",				//Url Format
        	false
        );

		proxy.token        = Twitter.get_token();
		proxy.token_secret = Twitter.get_token_secret();

		//Register a new warning service
		receivers.append(new WarningService("UserStream"));
	}


	public void register(IMessageReceiver receiver) {
		receivers.append(receiver);
	}




	public void start() {
		var call = proxy.new_call();
		call.set_function("1.1/user.json");
		call.set_method("GET");
		try{
			call.continuous(parse_data_cb, this);
		} catch (GLib.Error e) {
			error(e.message);
		}
	}



	private void parse_data_cb(Rest.ProxyCall call, string buf, size_t length,
	                           Error? error) {
		string real = buf.substring(0, (int)length);

		data.append(real);

		if(real.has_suffix("\r\n")) {
			if(real == "\r\n") {
				data.erase();
				return;
			}

			stdout.printf("USING DATA:\n%s\n", data.str);

			var parser = new Json.Parser();
			parser.load_from_data(data.str);

			var root = parser.get_root().get_object();

			StreamMessageType type = 0;

			if(root.has_member("delete"))
				type = StreamMessageType.DELETE;
			else if(root.has_member("scrub_geo"))
				type = StreamMessageType.SCRUB_GEO;
			else if(root.has_member("limit"))
				type = StreamMessageType.LIMIT;
			else if(root.has_member("disconnect"))
				type = StreamMessageType.DISCONNECT;
			else if(root.has_member("friends"))
				type = StreamMessageType.FRIENDS;
			else if(root.has_member("text"))
				type = StreamMessageType.TWEET;
			else if(root.has_member("event"))
				type = StreamMessageType.EVENT;
			else if(root.has_member("warning"))
				type = StreamMessageType.WARNING;


			foreach(IMessageReceiver it in receivers){
				it.stream_message_received(type, root);
			}


			data.erase();
		}
	}

}


