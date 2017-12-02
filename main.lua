function love.load()
  g = {}
  g.money = 0
  g.loan = 0
  g.time = 0
  g.billrate = 10
  g.billamount = 100
  g.billdue = 20
  g.lastbill = -g.billrate
  g.loanamount = 1000
  g.loanrate = 12
  g.interestmin = 0.05
  g.interestmax = 0.2
  g.interestdur1 = 21
  g.interestdur2 = math.pi
  g.loans = {}
  g.bills = {}

  img = {}
  img.bg = love.graphics.newImage("data/bg.png")
  img.bill = {}
  for i = 1, 1 do
    img.bill[#img.bill + 1] = love.graphics.newImage("data/bill" .. i .. ".png")
  end
  img.loan = {}
  for i = 1, 1 do
    img.loan[#img.loan + 1] = love.graphics.newImage("data/loan" .. i .. ".png")
  end
end

function newBill(amount, title)
  local newbill = {}
  newbill.amount = amount or math.floor(love.math.random() * g.billamount / 2 + g.billamount / 2)
  newbill.time = g.time
  newbill.due = math.floor(love.math.random() * g.billdue / 2 + g.billdue / 2)
  newbill.title = title or ("Bill " .. (#g.bills + 1))
  newbill.paid = false
  newbill.img = img.bill[math.floor(love.math.random(1, #img.bill+1))] or img.bill[1]
  function newbill.draw(self)
    love.graphics.draw(self.img, 0, 0)
    love.graphics.print(self.title, 10, 5)
    love.graphics.print(self.amount, 10, 25)
  end
  function newbill.onclick(self)
    if g.money >= self.amount then
      g.money = g.money - self.amount
      self.paid = true
    end
  end
  g.bills[#g.bills+1] = newbill
end

function currentInterest()
  local sin1 = (math.sin(g.time / g.interestdur1 * math.pi * 2) + 1) / 2
  local sin2 = (math.sin(g.time / g.interestdur2 * math.pi * 2) + 1) / 2 / 10
  local minmax = g.interestmax - g.interestmin
  return math.floor(((sin1 + sin2) * minmax + g.interestmin) * 100) / 100
end

function newLoan()
  local newloan = {}
  newloan.amount = g.loanamount
  newloan.interest = currentInterest()
  newloan.starttime = g.time
  newloan.lastinterest = g.time
  newloan.img = img.loan[math.floor(love.math.random(1, #img.loan+1))] or img.loan[1]
  function newloan.draw(self)
    love.graphics.draw(self.img, 0, 0)
    love.graphics.print((self.interest * 100) .. "%", 10, 5)
  end
  g.money = g.money + newloan.amount
  g.loan = g.loan + newloan.amount

  g.loans[#g.loans+1] = newloan
end

function love.update(dt)
  g.time = g.time + dt
  if g.time - g.lastbill > g.billrate then
    newBill()
    g.lastbill = g.time
    g.billrate = g.billrate * 0.99
  end
  for idx, loan in ipairs(g.loans) do
    if g.time - loan.lastinterest > g.loanrate then
      newBill(loan.amount * loan.interest, "Interest")
      loan.lastinterest = g.time
    end
  end
end

function love.keyreleased(key, scancode)
  if scancode == "space" then
    newLoan()
  end
end

function love.draw()

  love.graphics.setColor(255, 255, 255)
  love.graphics.origin()
  love.graphics.draw(img.bg, 0, 0)

  love.graphics.setColor(255, 255, 255)
  love.graphics.origin()
  love.graphics.translate(600, 50)

  for idx, loan in ipairs(g.loans) do
    loan:draw()
    love.graphics.translate(0, 25)
    if idx % 20 == 0 then
      love.graphics.translate(40, -25*20)
    end
  end

  love.graphics.setColor(255, 255, 255)
  love.graphics.origin()
  love.graphics.translate(20, 50)

  for idx, bill in ipairs(g.bills) do
    if not bill.paid then
      bill:draw()
      love.graphics.translate(0, 25)
      if idx % 20 == 0 then
        love.graphics.translate(40, -25*20)
      end
    end
  end

  love.graphics.setColor(255, 255, 255)
  love.graphics.origin()
  love.graphics.translate(500, 50)
  love.graphics.setColor(255, 255, 0)
  love.graphics.print("Money: $ " .. g.money)
  love.graphics.translate(0, 20)
  love.graphics.setColor(255, 0, 0)
  love.graphics.print("Loan: $ " .. g.loan)
  love.graphics.translate(0, 20)
  love.graphics.setColor(255, 255, 255)
  love.graphics.print("Interest: " .. (currentInterest() * 100) .. "%")
  love.graphics.translate(0, 20)
end
