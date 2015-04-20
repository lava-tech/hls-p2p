package com.tvie.osmf.p2p.utils 
{
    import flash.errors.IOError;
    import flash.events.IOErrorEvent;
    import flash.net.URLLoader;
    import flash.net.URLLoaderDataFormat;
    import flash.net.URLRequest;
    import flash.net.URLRequestMethod;
    import flash.net.URLVariables;
	/**
     * ...
     * @author dista
     */
    public class RemoteLogger 
    {
        
        public function RemoteLogger() 
        {
        }
        
        public static function log(data:String):void {
            CONFIG::P2P_REMOTE_LOG
            {
                var params:URLVariables = new URLVariables();
                params.log = "" + (new Date()).getTime() + "|" + data;
                
                var request:URLRequest = new URLRequest();
                request.url = baseUrl;
                request.method = URLRequestMethod.POST;
                request.data = params;
                
                var loader:URLLoader = new URLLoader();
                loader.addEventListener(IOErrorEvent.IO_ERROR, function(event:IOError):void {
                })
                loader.dataFormat = URLLoaderDataFormat.VARIABLES;
                
                try {
                    loader.load(request);
                }
                catch (err:Error) {
                }
            }
        }
        
        public static var baseUrl:String;        
    }

}