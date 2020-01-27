*&---------------------------------------------------------------------*
*& Report ZBA_TR_UPLOAD
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
REPORT ZBA_TR_UPLOAD.
*======================================================================*
* Initial idea and first release by Igor Yaskevitch (IBS), 2003 *
* Enhancements by Sergei Korolev, 2005 (added import queue *
* manipulations, authority checking, minor interface improvements) *
*----------------------------------------------------------------------*
* Function : This is a utility tool for uploading binary *
* files of a transport request from a Client PC, *
* adding to an import queue and importing into the *
* system. *
*======================================================================*
type-pools: abap, sabc, stms.
constants: gc_tp_fillclient like stpa-command value 'FILLCLIENT'.
data:
  lt_request     type stms_tr_requests,
  lt_tp_maintain type stms_tp_maintains.

data:
  sl              type i,
  l_datafile(255) type c,
  datafiles       type i,
  ret             type i,
  ans             type c.
data:
  et_request_infos type stms_wbo_requests,
  request_info     type stms_wbo_request,
  system           type tmscsys-sysnam,
  request          like e070-trkorr.
data:
  folder     type string,
  retval     like table of ddshretval with header line,
  fldvalue   like help_info-fldvalue,
  transdir   type text255,
  filename   like authb-filename,
  trfile(20) type c.
data:
  begin of datatab occurs 0,
    buf(8192) type x,
  end of datatab.
data: len  type i,
      flen type i.
selection-screen comment /1(79) comm_sel.
parameters:
p_cofile(255) type c lower case obligatory.
selection-screen skip.
selection-screen begin of block b01 with frame title bl_title.
parameters:
  p_addque as checkbox default 'X',
  p_tarcli like tmsbuffer-tarcli
             default sy-mandt
             matchcode object h_t000,
  p_sepr   obligatory.
selection-screen end of block b01.

initialization.
  bl_title = '导入队列参数'(B01).
  comm_sel = '请选择co-file. 文件名必须以字母''K''开始.'(001).
  if sy-opsys = 'Windows NT'.
    p_sepr = '\'.
  else.
    p_sepr = '/'.
  endif.
** CALL FUNCTION 'WSAF_BUILD_SEPARATOR'
** IMPORTING
** separator = p_sepr
** EXCEPTIONS
** separator_not_maintained = 1
** wrong_call = 2
** wsaf_config_not_maintained = 3
** OTHERS = 4.
* IF sy-subrc NE 0.
* MESSAGE s001(00) WITH 'Unable to find out the separator symbol for the system.'(008).
* ENDIF.
at selection-screen on value-request for p_cofile.
  data:
    file        type file_table,
    rc          type i,
    title       type string,
    file_table  type filetable,
    file_filter type string value 'CO-files (K*.*)|K*.*||'.
  title = 'Select CO-file'(006).
  call method cl_gui_frontend_services=>file_open_dialog
    exporting
      window_title            = title
      file_filter             = file_filter
    changing
      file_table              = file_table
      rc                      = rc
    exceptions
      file_open_dialog_failed = 1
      cntl_error              = 2
      error_no_gui            = 3
      not_supported_by_gui    = 4
      others                  = 5.
  if sy-subrc <> 0.
    message id sy-msgid type sy-msgty number sy-msgno
    with sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
  endif.
  read table file_table into file index 1.
  p_cofile = file.

at selection-screen.
  data:
  file type string.
  sl = strlen( p_cofile ).
  if sl < 11.
    message e001(00)
    with 'Invalid co-file name format. File name format must be KNNNNNNN.SSS'(009).
  endif.
  sl = sl - 11.
  if p_cofile+sl(1) ne 'K'.
    message e001(00)
    with 'Invalid co-file name format. File name format must be KNNNNNNN.SSS'(009).
  endif.
  sl = sl + 1.
  if not p_cofile+sl(6) co '0123456789'.
    message e001(00)
    with 'Invalid co-file name format. File name format must be KNNNNNNN.SSS'(009).
  endif.
  sl = sl + 6.
  if p_cofile+sl(1) ne '.'.
    message e001(00)
    with 'Invalid co-file name format. File name format must be KNNNNNNN.SSS'(009).
  endif.
  sl = sl - 7.
  clear datafiles.
  l_datafile = p_cofile.
  l_datafile+sl(1) = 'R'.
  file = l_datafile.
  if cl_gui_frontend_services=>file_exist( file = file ) = 'X'.
    add 1 to datafiles.
  endif.
  l_datafile+sl(1) = 'D'.
  file = l_datafile.
  if cl_gui_frontend_services=>file_exist( file = file ) = 'X'.
    add 1 to datafiles.
  endif.
  sl = sl + 8.
  request = p_cofile+sl(3).
  sl = sl - 8.
  concatenate request p_cofile+sl(7) into request.
  translate request to upper case.
  if datafiles = 0.
    message e398(00)
    with 'Corresponding data-files of transport request'(010)
    request
    'not found.'(011).
  else.
    message s398(00)
    with datafiles
    'data-files have been found for transport request'(012)
    request.
  endif.

start-of-selection.
  data:
    parameter  type spar,
    parameters type table of spar.
  call function 'RSPO_R_SAPGPARAM'
    exporting
      name  = 'DIR_TRANS'
    importing
      value = transdir
    exceptions
      error = 1
      thers = 2.
  if sy-subrc <> 0.
    message id sy-msgid type 'E' number sy-msgno
    with sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
  endif.
  filename = p_cofile+sl(11).
  translate filename to upper case.
  concatenate transdir 'cofiles' filename
  into filename
  separated by p_sepr.
  open dataset filename for input in binary mode.
  ret = sy-subrc.
  close dataset filename.
  if not ret = 0.
    call function 'POPUP_TO_CONFIRM'
      exporting
        text_question  = 'Copy all files?'(A03)
      importing
        answer         = ans
      exceptions
        text_not_found = 1
        others         = 2.
  else.
    parameter-param = 'FILE'.
    parameter-value = filename.
    append parameter to parameters.
    call function 'POPUP_TO_CONFIRM'
      exporting
        text_question  = 'File ''&FILE&'' already exists. Rewrite?'(A04)
      importing
        answer         = ans
      tables
        parameter      = parameters
      exceptions
        text_not_found = 1
        others         = 2.
  endif.
  check ans = '1'.
  trfile = p_cofile+sl(11).
  translate trfile to upper case.
  perform  copy_file using 'cofiles' trfile p_cofile.
  trfile(1) = 'R'.
  l_datafile+sl(1) = 'R'.
  perform  copy_file using 'data' trfile l_datafile.
  if datafiles > 1.
    trfile(1) = 'D'.
    l_datafile+sl(1) = 'D'.
    perform  copy_file using 'data' trfile l_datafile.
  endif.
  if p_addque = 'X'.
    system = sy-sysid.
    do 1 times.
* Check authority to add request to the import queue
      call function 'TR_AUTHORITY_CHECK_ADMIN'
        exporting
          iv_adminfunction = 'TADD'
        exceptions
          e_no_authority   = 1
          e_invalid_user   = 2
          others           = 3.
      if sy-subrc <> 0.
        message id sy-msgid type sy-msgty number sy-msgno
        with sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
        exit.
      endif.
      call function 'TMS_UI_APPEND_TR_REQUEST'
        exporting
          iv_system             = system
          iv_request            = request
          iv_expert_mode        = 'X'
          iv_ctc_active         = 'X'
        exceptions
          cancelled_by_user     = 1
          append_request_failed = 2
          others                = 3.
      check sy-subrc = 0.
      call function 'TMS_MGR_READ_TRANSPORT_REQUEST'
        exporting
          iv_request                 = request
          iv_target_system           = system
        importing
          et_request_infos           = et_request_infos
        exceptions
          read_config_failed         = 1
          table_of_requests_is_empty = 2
          system_not_available       = 3
          others                     = 4.
      clear request_info.
      read table et_request_infos into request_info index 1.
      if request_info-e070-korrdev = 'CUST'
      and not p_tarcli is initial.
        call function 'TMS_MGR_MAINTAIN_TR_QUEUE'
          exporting
            iv_command                 = gc_tp_fillclient
            iv_system                  = system
            iv_request                 = request
            iv_tarcli                  = p_tarcli
            iv_monitor                 = 'X'
            iv_verbose                 = 'X'
          importing
            et_tp_maintains            = lt_tp_maintain
          exceptions
            read_config_failed         = 1
            table_of_requests_is_empty = 2
            others                     = 3.
        if sy-subrc <> 0.
          message id sy-msgid type sy-msgty number sy-msgno
          with sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
          exit.
        endif.
      endif.
* Check authority to start request import
      call function 'TR_AUTHORITY_CHECK_ADMIN'
        exporting
          iv_adminfunction = 'IMPS'
        exceptions
          e_no_authority   = 1
          e_invalid_user   = 2
          others           = 3.
      if sy-subrc <> 0.
        message id sy-msgid type sy-msgty number sy-msgno
        with sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
        exit.
      endif.
      call function 'TMS_UI_IMPORT_TR_REQUEST'
        exporting
          iv_system             = system
          iv_request            = request
          iv_tarcli             = p_tarcli
          iv_some_active        = space
        exceptions
          cancelled_by_user     = 1
          import_request_denied = 2
          import_request_failed = 3
          others                = 4.
    enddo.
  endif.
*&--------------------------------------------------------------------*
*& Form. copy_file
*&--------------------------------------------------------------------*
* text
*---------------------------------------------------------------------*
* -->SUBDIR text
* -->FNAME text
* -->SOURCE_FILEtext
*---------------------------------------------------------------------*
form  copy_file using subdir fname source_file.
  data: l_filename type string.
  l_filename = source_file.
  concatenate transdir subdir fname
  into filename
  separated by p_sepr.
  refresh datatab.
  clear flen.
  call method cl_gui_frontend_services=>gui_upload
    exporting
      filename                = l_filename
      filetype                = 'BIN'
    importing
      filelength              = flen
    changing
      data_tab                = datatab[]
    exceptions
      file_open_error         = 1
      file_read_error         = 2
      no_batch                = 3
      gui_refuse_filetransfer = 4
      invalid_type            = 5
      no_authority            = 6
      unknown_error           = 7
      bad_data_format         = 8
      header_not_allowed      = 9
      separator_not_allowed   = 10
      header_too_long         = 11
      unknown_dp_error        = 12
      access_denied           = 13
      dp_out_of_memory        = 14
      disk_full               = 15
      dp_timeout              = 16
      not_supported_by_gui    = 17
      error_no_gui            = 18
      others                  = 19.
  if sy-subrc ne 0.
    write: / 'Error uploading file'(003), l_filename.
    exit.
  endif.
  call function 'AUTHORITY_CHECK_DATASET'
    exporting
      activity         = sabc_act_write
      filename         = filename
    exceptions
      no_authority     = 1
      activity_unknown = 2
      others           = 3.
  if sy-subrc <> 0.
    format color col_negative.
    write: / 'Write access denied. File'(013), filename.
    format color off.
    exit.
  endif.
  open dataset filename for output in binary mode.
  if sy-subrc ne 0.
    write: / 'File open error'(004), trfile.
    exit.
  endif.
  loop at datatab.
    if flen <= 8192.
      len = flen.
    else.
      len = 8192.
    endif.
    transfer datatab-buf to filename length len.
    flen = flen - len.
  endloop.
  close dataset filename.
  write: / 'File'(005), trfile, 'uploaded'(007).
endform. "copy_file
