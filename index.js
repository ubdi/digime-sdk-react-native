/* eslint no-console: 0 */
import { NativeDigime } from "./native";
import {
  split,
  pipe,
  map,
  filter,
  allPass,
  toPairs,
  path,
  values
} from "ramda";

class DigiMe {
  constructor() {
    this.bridge = NativeDigime.getNativeBridge();
    this.module = this.bridge.getModule();

    this.init();

    this._filesRetrieved = {};
    this._filesRetrieveFailed = {};
  }

  init() {
    this._waitForEvents({
      on: ["nativeLog"],
      cb: message => {
        console.log("Log from bridge: ", message);
      }
    });

    return this.module.initSDK();
  }

  authorize = async () => {
    console.log("[digi.me] Initiated authorization via SDK");

    try {
      const session = await this.module.authorize();
      if (!session) {
        console.log(
          "[digi.me] Authorization went through, but got empty session"
        );
        throw new Error("Invalid session");
      }

      console.log("[digi.me] Authorization successful", session);
      return session;
    } catch (error) {
      console.log("[digi.me] Authorization failed", error);
      throw error;
    }
  };

  getAccounts = async () => {
    console.log("[digime] Initiated getAccounts via SDK");

    try {
      const accounts = await this.module.getAccounts();
      console.log("[digime] Got Accounts", accounts);
      return accounts;
    } catch (error) {
      console.log("[digi.me] Get Accounts failed", error);
      throw error;
    }
  };

  getFiles = async (filters, onFileReceived) => {
    console.log("[digime] Initiated getFiles stream");

    try {
      // Listen for files, notify listener
      this.bridge.addListener(
        "fileReceiveSuccess",
        this._onFileRetrieved(filters, onFileReceived)
      );

      // Will resolve when all files are in
      await this.module.getFiles();
      console.log("[digime] Get Files Stream is completed");
    } catch (warning) {
      // We are ignoring failure from SDK, because it is not real failure yet
      // TOOD: distinguish real fail from warning on SDK level, and then stop
      // swallowing exceptions here
      console.warn("[digi.me] Get Files Stream Ended with a warning", warning);
    }

    return values(this._filesRetrieved);
  };

  _onFileRetrieved = (filters, onFileReceived) => data => {
    if (data) {
      const { fileId, json } = JSON.parse(data);
      console.log("Retrieved", fileId, json.length);

      const filterPredicates = getConditionPredicates(filters);
      const fileInfo = parseFileId(fileId);
      const file = {
        ...fileInfo,
        data: json
      };

      if (allPass(filterPredicates)(fileInfo)) {
        onFileReceived && onFileReceived(file);
        this._filesRetrieved[fileId] = file;
        return file;
      }
    }
  };

  _waitForEvents = ({ on, cb, off = [] }) => {
    on.forEach(event => {
      this.bridge.addListener(event, data => {
        cb(data);
        off.forEach(e => this.bridge.removeListener(e));
      });
    });
  };
}

const parseFileId = fileId => {
  const [, , serviceId, accountId, objectTypeId, dateRange] = split(
    "_",
    fileId
  );

  const date = {
    year: parseInt(dateRange.substr(1, 4)),
    month: parseInt(dateRange.substr(5, 2))
  };

  return {
    fileId,
    serviceId: parseInt(serviceId),
    accountId,
    objectTypeId: parseInt(objectTypeId),
    date
  };
};

// returns predicate fns for matching object path with provided array of seeked values
const getConditionPredicates = pipe(
  toPairs,
  filter(([, match]) => !!match),
  map(([keys, match]) => value => match.includes(path(keys.split("."))(value)))
);

export default new DigiMe();
