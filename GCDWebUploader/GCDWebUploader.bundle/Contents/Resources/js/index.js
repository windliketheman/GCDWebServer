/*
 Copyright (c) 2012-2019, Pierre-Olivier Latour
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.
 * The name of Pierre-Olivier Latour may not be used to endorse
 or promote products derived from this software without specific
 prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL PIERRE-OLIVIER LATOUR BE LIABLE FOR ANY
 DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

var ENTER_KEYCODE = 13;

var _path = null;
var _pendingReloads = [];
var _reloadingDisabled = 0;
var _folderUploadMap = {};
var _pendingCreates = 0;

function formatFileSize(bytes) {
  if (bytes >= 1000000000) {
    return (bytes / 1000000000).toFixed(2) + ' GB';
  }
  if (bytes >= 1000000) {
    return (bytes / 1000000).toFixed(2) + ' MB';
  }
  return (bytes / 1000).toFixed(2) + ' KB';
}

function _showError(message, textStatus, errorThrown) {
  $("#alerts").prepend(tmpl("template-alert", {
    level: "danger",
    title: (errorThrown != "" ? errorThrown : textStatus) + ": ",
    description: message
  }));
}

function _disableReloads() {
  _reloadingDisabled += 1;
}

function _enableReloads() {
  _reloadingDisabled -= 1;
  
  if (_pendingReloads.length > 0) {
    _reload(_pendingReloads.shift());
  }
}

function _reload(path) {
  if (_reloadingDisabled) {
    if ($.inArray(path, _pendingReloads) < 0) {
      _pendingReloads.push(path);
    }
    return;
  }
  
  _disableReloads();
  $.ajax({
    url: 'list',
    type: 'GET',
    data: {path: path},
    dataType: 'json'
  }).fail(function(jqXHR, textStatus, errorThrown) {
    _showError("Failed retrieving contents of \"" + path + "\"", textStatus, errorThrown);
  }).done(function(data, textStatus, jqXHR) {
    var scrollPosition = $(document).scrollTop();
    
    if (path != _path) {
      $("#path").empty();
      if (path == "/") {
        $("#path").append('<li class="active">' + _device + '</li>');
      } else {
        $("#path").append('<li data-path="/"><a>' + _device + '</a></li>');
        var components = path.split("/").slice(1, -1);
        for (var i = 0; i < components.length - 1; ++i) {
          var subpath = "/" + components.slice(0, i + 1).join("/") + "/";
          $("#path").append('<li data-path="' + subpath + '"><a>' + components[i] + '</a></li>');
        }
        $("#path > li").click(function(event) {
          _reload($(this).data("path"));
          event.preventDefault();
        });
        $("#path").append('<li class="active">' + components[components.length - 1] + '</li>');
      }
      _path = path;
    }
    
    $("#listing").empty();
    for (var i = 0, file; file = data[i]; ++i) {
      $(tmpl("template-listing", file)).data(file).appendTo("#listing");
    }
    
    $(".edit").editable(function(value, settings) { 
      var name = $(this).parent().parent().data("name");
      if (value != name) {
        var path = $(this).parent().parent().data("path");
        $.ajax({
          url: 'move',
          type: 'POST',
          data: {oldPath: path, newPath: _path + value},
          dataType: 'json'
        }).fail(function(jqXHR, textStatus, errorThrown) {
          _showError("Failed moving \"" + path + "\" to \"" + _path + value + "\"", textStatus, errorThrown);
        }).always(function() {
          _reload(_path);
        });
      }
      return value;
    }, {
      onedit: function(settings, original) {
        _disableReloads();
      },
      onsubmit: function(settings, original) {
        _enableReloads();
      },
      onreset: function(settings, original) {
        _enableReloads();
      },
      tooltip: 'Click to rename...'
    });
    
    $(".button-download").click(function(event) {
      var path = $(this).closest("tr").data("path");
      setTimeout(function() {
        window.location = "download?path=" + encodeURIComponent(path);
      }, 0);
    });
    
    $(".button-open").click(function(event) {
      var path = $(this).closest("tr").data("path");
      _reload(path);
    });
    
    $(".button-move").click(function(event) {
      var path = $(this).closest("tr").data("path");
      if (path[path.length - 1] == "/") {
        path = path.slice(0, path.length - 1);
      }
      $("#move-input").data("path", path);
      $("#move-input").val(path);
      $("#move-modal").modal("show");
    });
    
    $(".button-delete").click(function(event) {
      var path = $(this).closest("tr").data("path");
      $.ajax({
        url: 'delete',
        type: 'POST',
        data: {path: path},
        dataType: 'json'
      }).fail(function(jqXHR, textStatus, errorThrown) {
        _showError("Failed deleting \"" + path + "\"", textStatus, errorThrown);
      }).always(function() {
        _reload(_path);
      });
    });
    
    $(document).scrollTop(scrollPosition);
  }).always(function() {
    _enableReloads();
  });
}

$(document).ready(function() {
  
  // Workaround Firefox and IE not showing file selection dialog when clicking on upload buttons.
  $("#upload-file").click(function(event) {
    $("#fileupload").click();
  });
  $("#upload-folder").click(function(event) {
    $("#folderupload").click();
  });

  // Prevent event bubbling when using workaround above
  $("#fileupload, #folderupload").click(function(event) {
    event.stopPropagation();
  });

  var fileUploader = $("#fileupload").fileupload({
    dropZone: null,
    pasteZone: null,
    autoUpload: true,
    sequentialUploads: true,
    
    url: 'upload',
    type: 'POST',
    dataType: 'json',
    
    start: function(e) {
      $(".uploading").show();
    },
    
    stop: function(e) {
      $(".uploading").hide();
    },
    
    add: function(e, data) {
      var file = data.files[0];
      data.paramName = data.paramName || 'files[]';
      data.formData = { path: _path };
      data.context = $(tmpl("template-uploads", {
        path: _path + file.name
      })).appendTo("#uploads");
      var jqXHR = data.submit();
      data.context.find("button").click(function(event) {
        jqXHR.abort();
      });
    },
    
    progress: function(e, data) {
      var progress = parseInt(data.loaded / data.total * 100, 10);
      data.context.find(".progress-bar").css("width", progress + "%");
    },
    
    done: function(e, data) {
      _reload(_path);
    },
    
    fail: function(e, data) {
      var file = data.files[0];
      if (data.errorThrown != "abort") {
        _showError("Failed uploading \"" + file.name + "\" to \"" + _path + "\"", data.textStatus, data.errorThrown);
      }
    },
    
    always: function(e, data) {
      data.context.remove();
    },
    
  });

  var uploader = $("#folderupload").fileupload({
    dropZone: null,
    pasteZone: null,
    autoUpload: true,
    sequentialUploads: true,
    // limitConcurrentUploads: 2,
    // forceIframeTransport: true,
    
    url: 'upload',
    type: 'POST',
    dataType: 'json',
    
    start: function(e) {
      $(".uploading").show();
    },
    
    stop: function(e) {
      $(".uploading").hide();
      _folderUploadMap = {};
    },
    
    add: function(e, data) {
      var file = data.files[0];
      var existingFormData = data.formData || {};
      var formMap = {};
      if ($.isArray(existingFormData)) {
        for (var i = 0; i < existingFormData.length; i++) {
          var item = existingFormData[i];
          if (item && item.name) {
            formMap[item.name] = item.value;
          }
        }
      } else {
        formMap = existingFormData;
      }
      var relativePath = formMap.relativePath || (file.webkitRelativePath && file.webkitRelativePath.length ? file.webkitRelativePath : null);
      var uploadPath = formMap.path || _path;
      var uploadId = formMap.uploadId || null;
      if (!uploadId && relativePath) {
        var rootName = relativePath.split("/")[0];
        var mapKey = uploadPath + "|" + rootName;
        if (!_folderUploadMap[mapKey]) {
          _folderUploadMap[mapKey] = Date.now().toString() + "-" + Math.random().toString(36).slice(2, 8);
        }
        uploadId = _folderUploadMap[mapKey];
      }
      data.paramName = data.paramName || 'files[]';
      var formData = {
        path: uploadPath,
        uploadId: uploadId
      };
      if (relativePath) {
        formData.relativePath = relativePath;
      }
      data.formData = formData;
      data.context = $(tmpl("template-uploads", {
        path: uploadPath + (relativePath ? relativePath : file.name)
      })).appendTo("#uploads");
      var jqXHR = data.submit();
      data.context.find("button").click(function(event) {
        jqXHR.abort();
      });
    },
    
    progress: function(e, data) {
      var progress = parseInt(data.loaded / data.total * 100, 10);
      data.context.find(".progress-bar").css("width", progress + "%");
    },
    
    done: function(e, data) {
      _reload(_path);
    },
    
    fail: function(e, data) {
      var file = data.files[0];
      if (data.errorThrown != "abort") {
        _showError("Failed uploading \"" + file.name + "\" to \"" + _path + "\"", data.textStatus, data.errorThrown);
      }
    },
    
    always: function(e, data) {
      data.context.remove();
    },
    
  });

  function _submitFile(file, relativePath, uploadId) {
    var formData = { path: _path, uploadId: uploadId };
    if (relativePath) {
      formData.relativePath = relativePath;
    }
    uploader.fileupload('add', {
      files: [file],
      formData: formData
    });
  }

  function _submitFileWithPath(file, uploadPath) {
    uploader.fileupload('add', {
      files: [file],
      formData: {
        path: uploadPath
      }
    });
  }

  function _finishCreate() {
    _pendingCreates = Math.max(0, _pendingCreates - 1);
    if (_pendingCreates === 0) {
      if (!_reloadingDisabled) {
        var pathToReload = _path || "/";
        $("#reload").trigger("click");
        setTimeout(function() {
          _reload(pathToReload);
        }, 100);
      } else if ($.inArray(_path, _pendingReloads) < 0) {
        _pendingReloads.push(_path);
      }
    }
  }

  function _createDirectory(relativePath, uploadId) {
    if (!relativePath || !relativePath.length) {
      return;
    }
    _pendingCreates += 1;
    $.ajax({
      url: 'create-upload',
      type: 'POST',
      data: { path: _path, relativePath: relativePath, uploadId: uploadId },
      dataType: 'json'
    }).done(function() {
      _finishCreate();
    }).fail(function(jqXHR, textStatus, errorThrown) {
      _showError("Failed creating folder \"" + relativePath + "\"", textStatus, errorThrown);
      _finishCreate();
    });
  }

  function _normalizeEntryPath(entry) {
    if (entry.fullPath && entry.fullPath.length) {
      return entry.fullPath.replace(/^\/+/, '');
    }
    return entry.name || '';
  }

  function _normalizeFilePath(entry, file) {
    if (entry.fullPath && entry.fullPath.length) {
      return entry.fullPath.replace(/^\/+/, '');
    }
    return file && file.name ? file.name : '';
  }

  function _walkEntry(entry, uploadId) {
    if (entry.isFile) {
      entry.file(function(file) {
        var relativePath = _normalizeFilePath(entry, file);
        _submitFile(file, relativePath, uploadId);
      });
    } else if (entry.isDirectory) {
      var dirPath = _normalizeEntryPath(entry);
      _createDirectory(dirPath, uploadId);
      var reader = entry.createReader();
      reader.readEntries(function(entries) {
        for (var i = 0; i < entries.length; i++) {
          _walkEntry(entries[i], uploadId);
        }
      });
    }
  }

  function _stripRootPath(fullPath, rootName) {
    var normalized = fullPath.replace(/^\/+/, '');
    if (rootName && normalized.indexOf(rootName + '/') === 0) {
      return normalized.substring(rootName.length + 1);
    }
    return normalized;
  }

  function _walkEntryWithBase(entry, rootName, mappedBasePath) {
    if (entry.isFile) {
      entry.file(function(file) {
        var fullPath = _normalizeFilePath(entry, file);
        var subPath = _stripRootPath(fullPath, rootName);
        var subDir = '';
        if (subPath.indexOf('/') >= 0) {
          subDir = subPath.substring(0, subPath.lastIndexOf('/'));
        }
        var uploadPath = mappedBasePath;
        if (subDir.length) {
          uploadPath = uploadPath + '/' + subDir;
        }
        _submitFileWithPath(file, uploadPath);
      });
    } else if (entry.isDirectory) {
      var reader = entry.createReader();
      reader.readEntries(function(entries) {
        for (var i = 0; i < entries.length; i++) {
          _walkEntryWithBase(entries[i], rootName, mappedBasePath);
        }
      });
    }
  }

  function _walkEntry(entry, uploadId) {
    if (entry.isFile) {
      entry.file(function(file) {
        var relativePath = entry.fullPath ? entry.fullPath.replace(/^\//, '') : file.name;
        _submitFile(file, relativePath, uploadId);
      });
    } else if (entry.isDirectory) {
      var dirPath = entry.fullPath ? entry.fullPath.replace(/^\//, '') : entry.name;
      if (dirPath) {
        _createDirectory(dirPath, uploadId);
      }
      var reader = entry.createReader();
      reader.readEntries(function(entries) {
        for (var i = 0; i < entries.length; i++) {
          _walkEntry(entries[i], uploadId);
        }
      });
    }
  }

  function _handleDrop(event) {
    event.preventDefault();
    event.stopPropagation();

    var items = event.originalEvent.dataTransfer.items;
    if (!items || !items.length) {
      return;
    }

    var folderHandled = false;
    for (var i = 0; i < items.length; i++) {
      var item = items[i];
      if (!item.webkitGetAsEntry) {
        continue;
      }
      var entry = item.webkitGetAsEntry();
      if (entry && entry.isDirectory) {
        folderHandled = true;
        var rootName = entry.name;
        var mapKey = _path + '|' + rootName;
        if (!_folderUploadMap[mapKey]) {
          _folderUploadMap[mapKey] = Date.now().toString() + '-' + Math.random().toString(36).slice(2, 8);
        }
        var uploadId = _folderUploadMap[mapKey];
        _pendingCreates += 1;
        $.ajax({
          url: 'create-upload',
          type: 'POST',
          data: { path: _path, relativePath: rootName, uploadId: uploadId },
          dataType: 'json'
        }).done(function(response) {
          var mappedPath = response && response.path ? response.path : (_path + rootName);
          _walkEntryWithBase(entry, rootName, mappedPath);
          _finishCreate();
        }).fail(function(jqXHR, textStatus, errorThrown) {
          _showError("Failed creating folder \"" + rootName + "\"", textStatus, errorThrown);
          _finishCreate();
        });
      }
    }

    if (!folderHandled) {
      var files = event.originalEvent.dataTransfer.files;
      if (files && files.length) {
        uploader.fileupload('add', { files: files });
      }
    }
  }

  $(document).on('dragover', function(event) {
    event.preventDefault();
  });

  $(document).on('drop', _handleDrop);
  
  $("#create-input").keypress(function(event) {
    if (event.keyCode == ENTER_KEYCODE) {
      $("#create-confirm").click();
    };
  });
  
  $("#create-modal").on("shown.bs.modal", function(event) {
    $("#create-input").focus();
    $("#create-input").select();
  });
  
  $("#create-folder").click(function(event) {
    $("#create-input").val("Untitled folder");
    $("#create-modal").modal("show");
  });
  
  $("#create-confirm").click(function(event) {
    $("#create-modal").modal("hide");
    var name = $("#create-input").val();
    if (name != "") {
      $.ajax({
        url: 'create',
        type: 'POST',
        data: {path: _path + name},
        dataType: 'json'
      }).fail(function(jqXHR, textStatus, errorThrown) {
        _showError("Failed creating folder \"" + name + "\" in \"" + _path + "\"", textStatus, errorThrown);
      }).always(function() {
        _reload(_path);
      });
    }
  });
  
  $("#move-input").keypress(function(event) {
    if (event.keyCode == ENTER_KEYCODE) {
      $("#move-confirm").click();
    };
  });
  
  $("#move-modal").on("shown.bs.modal", function(event) {
    $("#move-input").focus();
    $("#move-input").select();
  })
  
  $("#move-confirm").click(function(event) {
    $("#move-modal").modal("hide");
    var oldPath = $("#move-input").data("path");
    var newPath = $("#move-input").val();
    if ((newPath != "") && (newPath[0] == "/") && (newPath != oldPath)) {
      $.ajax({
        url: 'move',
        type: 'POST',
        data: {oldPath: oldPath, newPath: newPath},
        dataType: 'json'
      }).fail(function(jqXHR, textStatus, errorThrown) {
        _showError("Failed moving \"" + oldPath + "\" to \"" + newPath + "\"", textStatus, errorThrown);
      }).always(function() {
        _reload(_path);
      });
    }
  });
  
  $("#reload").click(function(event) {
    _reload(_path);
  });
  
  _reload("/");
  
});
