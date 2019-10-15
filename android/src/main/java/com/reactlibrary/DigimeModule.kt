package com.mobileubdiapp

import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.modules.core.DeviceEventManagerModule
import com.google.gson.GsonBuilder
import me.digi.sdk.DMEPullClient
import me.digi.sdk.entities.DMEPullConfiguration
import me.digi.sdk.utilities.crypto.DMECryptoUtilities

internal class File(var fileId: String, var json: String)

class DigimeModule(reactContext: ReactApplicationContext) : ReactContextBaseJavaModule(reactContext) {
    private lateinit var client: DMEPullClient
    private val activity = currentActivity
    val gson = GsonBuilder().setPrettyPrinting().create()

    private val TAG = "DigimeModule"

    override fun getName(): String {
        return "Digime"
    }

    private fun sendEvent(eventName: String, data: String? = null) {
        super.getReactApplicationContext()
            .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
            .emit(eventName, data)
    }

    private fun sendLog(data: String) {
        sendEvent("nativeLog", data)
    }

    @ReactMethod
    fun initSDK() {
        if (currentActivity == null) {
            sendLog("Trying initSDK, but Activity is missing")
            return
        }

        sendLog("Initing SDK client...")

        val pk = DMECryptoUtilities(currentActivity!!.applicationContext).privateKeyHexFrom(
                currentActivity!!.applicationContext.getString(R.string.digime_contract_id) + ".p12",
                currentActivity!!.applicationContext.getString(R.string.digime_passphrase)
        )
        val cfg = DMEPullConfiguration(
                currentActivity!!.applicationContext.getString(R.string.digime_app_id),
                currentActivity!!.applicationContext.getString(R.string.digime_contract_id),
            pk
        )
        cfg.debugLogEnabled = true
        cfg.guestEnabled = false

        this.client = DMEPullClient(currentActivity!!.applicationContext, cfg)
    }

    @ReactMethod
    fun authorize(promise: Promise) {
        if (currentActivity == null) {
            sendLog("Trying authorize, but Activity is missing")
            return
        }

        sendLog("Authorizing...")
        client.authorize(currentActivity!!) { session, error ->
            when {
                error != null -> {
                    sendLog("authorize :: Error: " + error.toString())
                    promise.reject("authorizeFail", error)
                }
                session != null -> {
                    sendLog("authorize :: Accepted; Key ID: " + session.key)
                    promise.resolve(gson.toJson(session))
                }
            }
        }
    }

    @ReactMethod
    fun getAccounts(promise: Promise) {
        client.getSessionAccounts { accounts, error ->
            when {
                error != null -> {
                    sendLog("getAccounts :: Error: " + error.toString())
                    promise.reject("getAccountsFail", error)
                }
                accounts != null -> {
                    sendLog("getAccounts :: Completed; Size:" + accounts.size)
                    promise.resolve(gson.toJson(accounts))
                }
            }
        }
    }

    @ReactMethod
    fun getFiles(promise: Promise) {
        // Fetches all the available files in digi.me
        // This will be changed so it uses Scoping (once available in digi.me)
        client.getSessionData({ file, error ->
            if (error != null) {
                // We treat errors as warning, because we were told by digi.me to do so
                sendLog("getFiles :: File Receive Warning" + error.toString())
            }
            if (file != null) {
                sendLog("getFiles :: File Received:" + file.identifier)

                val fileJson = file.fileContentAsJSON()
                if (fileJson != null) {
                    val fileWithId = File(file.identifier, fileJson.asString)
                    sendEvent("fileReceiveSuccess", gson.toJson(fileWithId))
                } else {
                    sendLog("getFiles :: Received file " + file.identifier + " has invalid JSON")
                }
            } else sendLog("getFiles :: Received empty file")
        }) { error ->
            if (error != null) {
                // TODO: Treat this as a warning if it is of type IncompleteError
                sendLog("Get Files Error" + error.toString())
                promise.reject("getFilesFail", error)
            } else {
                promise.resolve(true)
            }
        }
    }
}

