import { NativeEventEmitter, NativeModules } from "react-native";

export class NativeDigime {
  static getNativeBridge() {
    if (!Digime._instance) {
      return new NativeDigime();
    }
  }

  constructor() {
    this.eventEmitter = new NativeEventEmitter(this.getModule());
    this._listeners = {};
  }

  getModule() {
    return NativeModules.Digime;
  }

  addListener(eventType, listener) {
    console.log("Adding listener", eventType);
    const listenerInstance = this.eventEmitter.addListener(eventType, listener);
    this._listeners[eventType] = listenerInstance;

    return listenerInstance;
  }

  removeListener(eventType) {
    if (this._listeners[eventType]) {
      console.log("Removing listener", eventType);
      this._listeners[eventType].remove();
      delete this._listeners[eventType];
    }
  }
}
