/* Copyright 2019 Ernesto Castellotti <erny.castell@gmail.com>
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/. 
 
 * Appendix by copyright onwer:
 * All files generated by this program are to be considered as the property 
 * of the copyright owner, any use (including commercial) is permitted on the 
 * condition of publicly mentioning the use of this software.
 */

module tlscheme2json; 

enum DEFAULT_TL_URL = "https://raw.githubusercontent.com/tdlib/td/master/td/generate/scheme/td_api.tl";

class TLMethod {
    string name;
    string type;
    string description;
}

class TLClass {
    string name;
    TLMethod[] methods;
    string description;
    string inheritance;
    string return_type;
    bool isFunction;
    bool isSynchronous;
}

class TLJson {
    TLClass[] tl_classes;
}

class TLScheme2Json {
    private string scheme;
    private TLClass[] classes;
    private bool functionHeaderFounded = false;
    private TLClass[] classList;

    this(string scheme) {
        this.scheme = scheme;
    }

    this() {
        import std.stdio : writeln;
        import std.net.curl : get;

        writeln("Obtaining TLScheme from " , DEFAULT_TL_URL);
        this.scheme = get(DEFAULT_TL_URL).dup;
    }

    void parse() {
        import std.array : split;
        import std.algorithm.searching : startsWith;
        import std.algorithm.searching : canFind;
        import std.array : empty;

        auto lines = this.scheme.split("\n");
        auto lineptr = lines.ptr;
        auto endptr = &lines[lines.length -1];

        while(true) {
            if(lineptr > endptr) {
                break;
            }

            auto line = *lineptr;

            if (line.empty) {
                lineptr++;
                continue;
            }

            if (line.startsWith("//@description")) {
                parseType(lineptr, this.functionHeaderFounded);
                continue;
            }

            if (line.startsWith("//@class")) {
                parseClass(*lineptr, this.functionHeaderFounded);
                lineptr++;
                continue;
            }

            if (line.canFind("---functions---")) {
                this.functionHeaderFounded = true;
                lineptr++;
                continue;
            }

            lineptr++;
        }
    }

    string toJson() {
        import asdf : serializeToJsonPretty;
        auto tljson = new TLJson();
        tljson.tl_classes = this.classList;
        return tljson.serializeToJsonPretty();
    }

    private void parseType(ref string* lineptr, bool isFunction) {
        auto tlClass = implParse(lineptr, isFunction);
        this.classList ~= tlClass;
    }

    private void parseClass(string line, bool isFunction) {
        import std.array : split;
        import std.array : replace;
        import std.string : strip;

        auto lineSplit = line.split("@");
        auto tlClass = new TLClass(); 
        tlClass.name = lineSplit[1].replace("class", "").strip();
        tlClass.description = lineSplit[2].replace("description", "").strip();
        tlClass.inheritance = "TLBaseClass";
        tlClass.isFunction = isFunction;
        this.classList ~= tlClass;
    }

    private TLClass implParse(ref string* lineptr, bool isFunction) {
        import std.array : empty;
        import std.array : split;
        import std.array : join;
        import std.array : replace;
        import std.string : stripLeft;
        import std.string : stripRight;
        import std.algorithm.searching : startsWith;
        import std.algorithm.searching : canFind;
        import std.uni : toLower;
        import std.stdio : writeln;

        string name;
        string description;
        string inheritance;
        string return_type;
        bool isSynchronous = false;
        TLMethod[] methods;

        string propertiesLines = lineptr[0].stripLeft("//");

        while(true) {
            auto line = *lineptr;
            lineptr++;

            if (line.startsWith("//@")) {
                propertiesLines ~= " " ~ line.stripLeft("//");
                continue;
            }

            if (line.startsWith("//-")) {
                propertiesLines ~= " " ~ line.stripLeft("//-");
                continue;
            }

            auto fields = line.split();
            name = fields[0];
            methods = new TLMethod[fields.length - 3];

            foreach (i, method; fields[1..fields.length -2]) {
                auto methodProperties = method.split(":");
                methods[i] = new TLMethod();
                methods[i].name = methodProperties[0];
                methods[i].type = methodProperties[1];
            }

            auto rawreturn = fields[fields.length -1].stripRight(";");

            if (rawreturn.toLower != name.toLower) {
                if(isFunction) {
                    foreach (tlClass; this.classList) {
                        if (tlClass.name.toLower == rawreturn.toLower) {
                            return_type = tlClass.name;
                        }
                    }
                } else {
                    inheritance = rawreturn;
                } 
            }

            if(inheritance == null) {
                inheritance = "BaseTLClass";
            }

            if(isFunction && return_type.empty) {
                writeln("[WARNING] return type has not been founded for function: ", name);
            }

            break;
        }

        auto properties = propertiesLines.split("@");
        foreach(property; properties[1..properties.length]) {
            auto propertySplit = property.split();

            if (propertySplit[0] == "description") {
                description = propertySplit[1..propertySplit.length].join(" ");
            } else {
                auto nameMethod = propertySplit[0].replace("param_", "");
                auto valueProperty  = propertySplit[1..propertySplit.length].join(" ");

                foreach(method; methods) {
                    if(method.name == nameMethod) {
                        method.description = valueProperty;
                    }
                }
            }
        }

        isSynchronous = description.canFind("Can be called synchronously");
        auto tlClass = new TLClass();
        tlClass.name = name;
        tlClass.methods = methods;
        tlClass.description = description;
        tlClass.inheritance = inheritance;
        tlClass.return_type = return_type;
        tlClass.isFunction = isFunction;
        tlClass.isSynchronous = isSynchronous;
        return tlClass;
    }
}