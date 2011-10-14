/*
Copyright (c) 2011 Flashphoner
All rights reserved. This Code and the accompanying materials
are made available under the terms of the GNU Public License v2.0
which accompanies this distribution, and is available at
http://www.gnu.org/licenses/old-licenses/gpl-2.0.html

Contributors:
    Flashphoner - initial API and implementation

This code and accompanying materials also available under LGPL and MPL license for Flashphoner buyers. Other license versions by negatiation. Write us support@flashphoner.com with any questions.
*/
package com.flashphoner.api
{	
	
	import com.adobe.cairngorm.control.CairngormEventDispatcher;
	import com.flashphoner.Logger;
	import com.flashphoner.api.data.ErrorCodes;
	import com.flashphoner.api.data.ModelLocator;
	import com.flashphoner.api.data.PhoneConfig;
	import com.flashphoner.api.interfaces.APINotify;
	
	import flash.net.NetConnection;
	import flash.net.NetStream;

	internal class PhoneCallback
	{	
		private var flash_API:Flash_API;
		public function PhoneCallback(flashAPI:Flash_API)
		{
			this.flash_API = flashAPI; 
		}
		
		public function notifyBalance(balance:Number,_sipObject:Object):void{
			for each (var apiNotify:APINotify in flash_API.apiNotifys){
				apiNotify.notifyBalance(balance,_sipObject);
			}
		}	
		
		public function getVersion(version:String):void{
			PhoneConfig.VERSION_OF_SERVER = version;
			for each (var apiNotify:APINotify in flash_API.apiNotifys){
				apiNotify.notifyVersion(PhoneConfig.getFullVersion());
			}
		}
		
		public function getUserData(resObj:Object):void{
			var modelLocator:ModelLocator = flash_API.modelLocator;
			modelLocator.login = resObj.login;
			modelLocator.pwd = resObj.password;
			modelLocator.sipProviderAddress = resObj.sipProviderAddress;
			modelLocator.sipProviderPort = resObj.sipProviderPort;
			
		}
		
		public function fail(errorCode:String,_sipObject:Object):void{
			Logger.info("PhoneCallback.fail() "+errorCode);
			if (errorCode == ErrorCodes.AUTHENTICATION_FAIL || errorCode == ErrorCodes.SIP_PORTS_BUSY){
				flash_API.dropRegisteredTimer();
			}			
			for each (var apiNotify:APINotify in flash_API.apiNotifys){
				apiNotify.notifyError(errorCode,_sipObject);
			}
		}
		
		public function close():void{
		}
		
		public function registered(_sipObject:Object):void{
			for each (var apiNotify:APINotify in flash_API.apiNotifys){
				apiNotify.notifyRegistered(_sipObject);
			}
			CairngormEventDispatcher.getInstance().dispatchEvent(new MainEvent(MainEvent.REGISTERED,flash_API));
		}
		
		public function ring(_call:Object,_sipObject:Object):void{
			var call:Call = process(_call);
			for each (var apiNotify:APINotify in flash_API.apiNotifys){
				apiNotify.notify(call,_sipObject);
			}
			if (!call.incoming){
				CairngormEventDispatcher.getInstance().dispatchEvent(new CallEvent(CallEvent.OUT,call));
			} else {
				CairngormEventDispatcher.getInstance().dispatchEvent(new CallEvent(CallEvent.IN,call));
			}
		}
		
		public function sessionProgress(_call:Object,_sipObject:Object):void{
			var call:Call = process(_call);
			CairngormEventDispatcher.getInstance().dispatchEvent(new CallEvent(CallEvent.SESSION_PROGRESS,call));
		}
		
		public function talk(_call:Object,_sipObject:Object):void{
			var call:Call = process(_call);
			for each (var apiNotify:APINotify in flash_API.apiNotifys){
				apiNotify.notify(call,_sipObject);
			}
			CairngormEventDispatcher.getInstance().dispatchEvent(new CallEvent(CallEvent.TALK,call));
		}
		
		public function hold(_call:Object, _sipObject:Object):void{
			var call:Call = process(_call);
			for each (var apiNotify:APINotify in flash_API.apiNotifys){
				apiNotify.notify(call,_sipObject);
			}
			CairngormEventDispatcher.getInstance().dispatchEvent(new CallEvent(CallEvent.HOLD,call));
		}
		
		// Notify about CIF 352x288 or QCIF 176x144 video format 
		public function notifyVideoFormat(_call:Object):void{
			var call:Call = process(_call);
			for each (var apiNotify:APINotify in flash_API.apiNotifys){
				apiNotify.notifyVideoFormat(call);			
			}
			CairngormEventDispatcher.getInstance().dispatchEvent(new CallEvent(CallEvent.VIDEO_FORMAT_CHANGED, call));
		}
		
		public function callbackHold(_call:Object, isHold:Boolean):void{
			var call:Call = process(_call);
			call.iHolded = isHold;
			if (!isHold){
				for each (var tempCall:Call in flash_API.calls){
					if (tempCall.state == Call.STATE_TALK && tempCall.id != call.id){
						tempCall.setStatusHold(true);
					}
				}
			}
			for each (var apiNotify:APINotify in flash_API.apiNotifys){
				apiNotify.notifyCallbackHold(call,isHold);
			}
		}
		public function busy(_call:Object,_sipObject:Object):void{
			var call:Call = process(_call);
			for each (var apiNotify:APINotify in flash_API.apiNotifys){
				apiNotify.notify(call,_sipObject);
			}
			CairngormEventDispatcher.getInstance().dispatchEvent(new CallEvent(CallEvent.BUSY,call));	
		}
		
		public function finish(_call:Object,_sipObject:Object):void{
			var call:Call = process(_call);
			for each (var apiNotify:APINotify in flash_API.apiNotifys){
				apiNotify.notify(call,_sipObject);
			}
			CairngormEventDispatcher.getInstance().dispatchEvent(new CallEvent(CallEvent.FINISH,call));
		}	
		
		public function process(_call:Object):Call{
			Logger.info("PhoneCallback.process() id="+_call.id+" state="+_call.state+" callee="+_call.callee);
			var call:Call = flash_API.getCallById(_call.id);
			if (call==null){
				call = new Call(flash_API);
				call.id = _call.id;	
			}

			if (_call.isIncomming == 'true'){
				call.incoming = true;
			}else{
				call.incoming = false;
			}
			if (_call.isVideoCall == 'true'){
				call.isVideoCall = true;
			}else{
				call.isVideoCall = false;
			} 
			call.callee = _call.callee;
			call.caller = _call.caller;
			if (call.incoming){
				call.anotherSideUser = _call.caller;
			}else{
				call.anotherSideUser = _call.callee;
			}
			call.visibleNameCallee = _call.visibleNameCallee;
			call.visibleNameCaller = _call.visibleNameCaller;
			call.state = _call.state;
			call.sip_state = _call.sip_state;
			call.playerVideoHeight = _call.playerVideoHeight;
			call.playerVideoWidth = _call.playerVideoWidth;
			call.streamerVideoWidth = _call.streamerVideoWidth;
			call.streamerVideoHeight = _call.streamerVideoHeight;
		
			flash_API.addCall(call);			
			Logger.info("PhoneCallback.process() complete id="+call.id+" state="+call.state+" callee="+call.callee);
			return call;
		}
		
		public function notifyMessage(messageObj:Object):void {
			Logger.info("Message has been accepted by other participant");
			CairngormEventDispatcher.getInstance().dispatchEvent(new MessageEvent(MessageEvent.MESSAGE_EVENT,messageObj,flash_API));		
		}		
		
	}
}